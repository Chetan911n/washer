import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function validShiftHours(value: unknown): value is Array<{ days: number[]; start: string; end: string }> {
  if (!Array.isArray(value) || value.length === 0 || value.length > 7) return false;
  return value.every((shift) => {
    if (!shift || typeof shift !== 'object') return false;
    const item = shift as Record<string, unknown>;
    return Array.isArray(item.days)
      && item.days.length > 0
      && item.days.length <= 7
      && item.days.every((day) => Number.isInteger(day) && day >= 0 && day <= 6)
      && typeof item.start === 'string'
      && /^([01]\d|2[0-3]):[0-5]\d$/.test(item.start)
      && typeof item.end === 'string'
      && /^([01]\d|2[0-3]):[0-5]\d$/.test(item.end)
      && item.start < item.end;
  });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'GET' && request.method !== 'POST') {
    return response({ error: 'Method not allowed' }, 405);
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return response({ error: 'Sign in as the owner.' }, 401);

  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const token = authorization.slice('Bearer '.length);
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: userResult, error: userError } = await userClient.auth.getUser(token);
    const owner = userResult.user;
    if (userError || !owner || owner.app_metadata?.role !== 'admin') {
      return response({ error: 'Owner authorization required.' }, 403);
    }
    const { data: assurance, error: assuranceError } =
      await userClient.auth.mfa.getAuthenticatorAssuranceLevel();
    if (assuranceError || assurance?.currentLevel !== 'aal2') {
      return response({ error: 'Complete owner two-factor authentication first.' }, 403);
    }

    const admin = createClient(url, serviceKey, { auth: { persistSession: false } });

    if (request.method === 'GET') {
      const { data: applications, error } = await admin
        .from('washers')
        .select('id, profile_id, society_id, area, requested_shift_hours, created_at')
        .eq('status', 'pending')
        .order('created_at', { ascending: true });
      if (error) throw error;

      const profileIds = [...new Set((applications ?? []).map((row) => row.profile_id))];
      const societyIds = [...new Set((applications ?? []).map((row) => row.society_id))];
      const [profilesResult, societiesResult] = await Promise.all([
        profileIds.length
          ? admin.from('profiles').select('id, full_name, avatar_path').in('id', profileIds)
          : Promise.resolve({ data: [], error: null }),
        societyIds.length
          ? admin.from('societies').select('id, name, city').in('id', societyIds)
          : Promise.resolve({ data: [], error: null }),
      ]);
      if (profilesResult.error) throw profilesResult.error;
      if (societiesResult.error) throw societiesResult.error;
      const profiles = new Map((profilesResult.data ?? []).map((row) => [row.id, row]));
      const societies = new Map((societiesResult.data ?? []).map((row) => [row.id, row]));

      const result = await Promise.all((applications ?? []).map(async (application) => {
        const idPath = `${application.profile_id}/identity.jpg`;
        const { data: signedDocument, error: signedDocumentError } = await admin
          .storage.from('washer-ids').createSignedUrl(idPath, 300);
        if (signedDocumentError) throw signedDocumentError;

        const profile = profiles.get(application.profile_id);
        const avatarPath = profile?.avatar_path;
        const avatar = avatarPath
          ? await admin.storage.from('avatars').createSignedUrl(avatarPath, 300)
          : null;
        if (avatar?.error) throw avatar.error;

        return {
          ...application,
          profile,
          society: societies.get(application.society_id),
          identity_document_url: signedDocument.signedUrl,
          avatar_url: avatar?.data?.signedUrl ?? null,
        };
      }));
      return response({ applications: result });
    }

    const body = await request.json();
    const applicationId = body?.applicationId;
    const decision = body?.decision;
    if (typeof applicationId !== 'string' || !/^[0-9a-f-]{36}$/i.test(applicationId)) {
      return response({ error: 'Choose a valid application.' }, 400);
    }
    if (decision !== 'approve' && decision !== 'reject') {
      return response({ error: 'Decision must be approve or reject.' }, 400);
    }

    const dailyCap = decision === 'approve' ? body.dailyCap : 0;
    const shiftHours = decision === 'approve' ? body.shiftHours : [];
    if (decision === 'approve'
      && (!Number.isInteger(dailyCap) || dailyCap < 1 || dailyCap > 100 || !validShiftHours(shiftHours))) {
      return response({ error: 'Set a valid daily cap and working shift before approval.' }, 400);
    }

    const { error: reviewError } = await admin.rpc('admin_review_washer_application', {
      target_washer_id: applicationId,
      decision,
      approved_daily_cap: dailyCap,
      approved_shift_hours: shiftHours,
      reviewing_admin_id: owner.id,
    });
    if (reviewError) {
      const status = reviewError.code === '42501' ? 403 : 409;
      return response({ error: reviewError.message }, status);
    }
    return response({ reviewed: true, applicationId, decision });
  } catch (error) {
    console.error('review-washer-application failed', error);
    return response({ error: 'Could not load or update washer applications.' }, 500);
  }
});
