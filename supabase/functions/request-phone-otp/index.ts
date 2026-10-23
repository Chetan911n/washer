import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function digest(value: string, pepper: string): Promise<string> {
  const bytes = new TextEncoder().encode(`${pepper}:${value}`);
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(hash)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return response({ error: 'Method not allowed' }, 405);

  try {
    const { phone, role, deviceId, registering } = await request.json();
    if (typeof phone !== 'string' || !/^\+[1-9]\d{7,14}$/.test(phone)) {
      return response({ error: 'Enter a valid phone number with country code.' }, 400);
    }
    if (role !== 'customer' && role !== 'washer') {
      return response({ error: 'Choose Customer or Washer.' }, 400);
    }
    if (typeof registering !== 'boolean') {
      return response({ error: 'Choose Register or Log in.' }, 400);
    }
    if (typeof deviceId !== 'string' || deviceId.length < 16 || deviceId.length > 128) {
      return response({ error: 'This device could not be verified. Restart the app and try again.' }, 400);
    }

    const url = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const pepper = Deno.env.get('OTP_RATE_LIMIT_PEPPER');
    if (!pepper) throw new Error('OTP_RATE_LIMIT_PEPPER is not configured');

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
    const [phoneHash, deviceHash] = await Promise.all([
      digest(phone, pepper),
      digest(deviceId, pepper),
    ]);
    const { data: decision, error: limitError } = await admin.rpc('reserve_otp_request', {
      requested_phone_hash: phoneHash,
      requested_device_hash: deviceHash,
    });
    if (limitError) throw limitError;
    if (decision !== 'ok') {
      const message = decision === 'device_hour'
        ? 'Too many codes were requested from this device. Try again later.'
        : 'Too many codes were requested for this phone. Try again later.';
      return response({ error: message }, 429);
    }

    const auth = createClient(url, anonKey, { auth: { persistSession: false } });
    const { error: authError } = await auth.auth.signInWithOtp({
      phone,
      options: {
        shouldCreateUser: registering,
        ...(registering ? { data: { role } } : {}),
      },
    });
    if (authError) return response({ error: authError.message }, 400);
    return response({ sent: true });
  } catch (error) {
    console.error('request-phone-otp failed', error);
    return response({ error: 'Could not send the code. Check your connection and try again.' }, 500);
  }
});
