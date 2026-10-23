(() => {
  const $ = (selector) => document.querySelector(selector);
  const configForm = $('#config-form');
  const signinForm = $('#signin-form');
  const mfaForm = $('#mfa-form');
  const config = JSON.parse(localStorage.getItem('society-wash-admin-config') || '{}');
  let accessToken = null;
  let refreshToken = null;
  let pendingFactors = [];

  if (config.url) $('#project-url').value = config.url;
  if (config.key) $('#anon-key').value = config.key;
  show('settings');

  function show(id) {
    for (const section of ['settings', 'signin', 'dashboard']) $(`#${section}`).classList.toggle('hidden', section !== id);
  }

  function setNotice(message = '') {
    const notice = $('#notice');
    notice.textContent = message;
    notice.classList.toggle('hidden', !message);
  }

  function toast(message) {
    const item = $('#toast');
    item.textContent = message;
    item.classList.remove('hidden');
    window.clearTimeout(toast.timer);
    toast.timer = window.setTimeout(() => item.classList.add('hidden'), 3600);
  }

  function endpoint(path) {
    return `${config.url.replace(/\/$/, '')}${path}`;
  }

  async function api(path, { method = 'GET', body, token = accessToken } = {}) {
    const response = await fetch(endpoint(path), {
      method,
      headers: {
        apikey: config.key,
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const result = response.status === 204 ? null : await response.json().catch(() => null);
    if (!response.ok) throw new Error(result?.msg || result?.message || result?.error_description || result?.error || `Request failed (${response.status}).`);
    return result;
  }

  configForm.addEventListener('submit', (event) => {
    event.preventDefault();
    const url = $('#project-url').value.trim().replace(/\/$/, '');
    const key = $('#anon-key').value.trim();
    if (!/^https:\/\//.test(url)) return toast('Enter a valid HTTPS Supabase project URL.');
    config.url = url;
    config.key = key;
    localStorage.setItem('society-wash-admin-config', JSON.stringify(config));
    show('signin');
  });

  signinForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = signinForm.querySelector('button');
    button.disabled = true;
    try {
      const session = await api('/auth/v1/token?grant_type=password', {
        method: 'POST',
        token: config.key,
        body: { email: $('#email').value.trim(), password: $('#password').value },
      });
      accessToken = session.access_token;
      refreshToken = session.refresh_token;
      const result = await api('/auth/v1/factors');
      pendingFactors = (result?.factors || []).filter((factor) => factor.factor_type === 'totp' && factor.status === 'verified');
      if (!pendingFactors.length) throw new Error('This owner account needs a verified authenticator app before it can review applications.');
      $('#mfa-code').value = '';
      signinForm.classList.add('hidden');
      mfaForm.classList.remove('hidden');
      $('#mfa-code').focus();
    } catch (error) {
      accessToken = null;
      toast(error.message || 'Could not sign in. Check the account and project settings.');
    } finally {
      button.disabled = false;
    }
  });

  mfaForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = mfaForm.querySelector('button');
    button.disabled = true;
    try {
      let verified = false;
      for (const factor of pendingFactors) {
        try {
          const challengeResult = await api(`/auth/v1/factors/${encodeURIComponent(factor.id)}/challenge`, { method: 'POST', body: {} });
          const result = await api(`/auth/v1/factors/${encodeURIComponent(factor.id)}/verify`, {
            method: 'POST',
            body: { challenge_id: challengeResult.id, code: $('#mfa-code').value.trim() },
          });
          accessToken = result.access_token;
          refreshToken = result.refresh_token || refreshToken;
          verified = true;
          break;
        } catch (_) { /* Try the next verified authenticator factor. */ }
      }
      if (!verified) throw new Error('That code could not be verified. Check your authenticator and try again.');
      mfaForm.classList.add('hidden');
      signinForm.classList.remove('hidden');
      signinForm.reset();
      show('dashboard');
      await loadApplications();
    } catch (error) {
      toast(error.message || 'Two-factor verification failed.');
    } finally {
      button.disabled = false;
    }
  });

  async function review(applicationId, decision, dailyCap = null, shiftHours = null) {
    await api('/functions/v1/review-washer-application', {
      method: 'POST',
      body: { applicationId, decision, ...(decision === 'approve' ? { dailyCap, shiftHours } : {}) },
    });
    toast(decision === 'approve' ? 'Washer approved.' : 'Application declined.');
    await loadApplications();
  }

  function dayChip(day, selected) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const label = document.createElement('label');
    label.className = 'day-option';
    const input = document.createElement('input');
    input.type = 'checkbox'; input.value = String(day); input.checked = selected;
    const span = document.createElement('span'); span.textContent = labels[day];
    label.append(input, span);
    return label;
  }

  function makeCard(application) {
    const card = document.createElement('article');
    card.className = 'application-card';
    const person = document.createElement('section'); person.className = 'person';
    const top = document.createElement('div'); top.className = 'person-top';
    const avatar = document.createElement(application.avatar_url ? 'img' : 'div');
    avatar.className = `avatar${application.avatar_url ? '' : ' avatar-empty'}`;
    if (application.avatar_url) { avatar.src = application.avatar_url; avatar.alt = 'Washer profile photo'; }
    else { avatar.textContent = (application.profile?.full_name || 'W').slice(0, 1).toUpperCase(); }
    const nameBlock = document.createElement('div');
    const name = document.createElement('h3'); name.textContent = application.profile?.full_name || 'Washer applicant';
    const applied = document.createElement('p'); applied.textContent = `Applied ${new Date(application.created_at).toLocaleDateString()}`;
    nameBlock.append(name, applied); top.append(avatar, nameBlock);
    const society = document.createElement('p'); society.className = 'detail'; society.textContent = `${application.society?.name || 'Society'} · ${application.society?.city || ''}`;
    const area = document.createElement('p'); area.className = 'detail'; area.textContent = `Work area: ${application.area}`;
    const documentLink = document.createElement('a'); documentLink.className = 'document-link'; documentLink.href = application.identity_document_url; documentLink.target = '_blank'; documentLink.rel = 'noopener'; documentLink.textContent = 'Open identity document ↗';
    person.append(top, society, area, documentLink);

    const reviewPane = document.createElement('section'); reviewPane.className = 'review';
    const heading = document.createElement('h4'); heading.className = 'review-title'; heading.textContent = 'Set approved work limits';
    const grid = document.createElement('div'); grid.className = 'review-grid';
    const capLabel = document.createElement('label'); capLabel.textContent = 'Jobs per day';
    const cap = document.createElement('input'); cap.type = 'number'; cap.min = '1'; cap.max = '100'; cap.value = '5'; capLabel.append(cap);
    const requested = application.requested_shift_hours?.[0] || { days: [1, 2, 3, 4, 5, 6], start: '07:00', end: '14:00' };
    const schedule = document.createElement('div'); schedule.className = 'schedule';
    const scheduleLabel = document.createElement('label'); scheduleLabel.textContent = 'Approved working days';
    const days = document.createElement('div'); days.className = 'days';
    for (let day = 0; day < 7; day++) days.append(dayChip(day, requested.days.includes(day)));
    const times = document.createElement('div'); times.className = 'times';
    const fromLabel = document.createElement('label'); fromLabel.textContent = 'Start time';
    const from = document.createElement('input'); from.type = 'time'; from.value = requested.start; fromLabel.append(from);
    const untilLabel = document.createElement('label'); untilLabel.textContent = 'End time';
    const until = document.createElement('input'); until.type = 'time'; until.value = requested.end; untilLabel.append(until);
    times.append(fromLabel, untilLabel); schedule.append(scheduleLabel, days, times);
    grid.append(capLabel);
    const requestInfo = document.createElement('p'); requestInfo.className = 'detail'; requestInfo.textContent = 'Suggested hours are prefilled from the applicant’s request.';
    const actions = document.createElement('div'); actions.className = 'decision-actions';
    const reject = document.createElement('button'); reject.className = 'button reject'; reject.type = 'button'; reject.textContent = 'Decline';
    const approve = document.createElement('button'); approve.className = 'button primary'; approve.type = 'button'; approve.textContent = 'Approve washer';
    reject.addEventListener('click', async () => {
      if (!window.confirm(`Decline ${application.profile?.full_name || 'this application'}?`)) return;
      reject.disabled = true;
      try { await review(application.id, 'reject'); } catch (error) { toast(error.message || 'Could not decline application.'); reject.disabled = false; }
    });
    approve.addEventListener('click', async () => {
      const selectedDays = [...days.querySelectorAll('input:checked')].map((input) => Number(input.value));
      const dailyCap = Number(cap.value);
      if (!Number.isInteger(dailyCap) || dailyCap < 1 || dailyCap > 100 || !selectedDays.length || from.value >= until.value) {
        return toast('Set a daily cap, at least one day, and valid working hours.');
      }
      approve.disabled = true;
      try { await review(application.id, 'approve', dailyCap, [{ days: selectedDays, start: from.value, end: until.value }]); }
      catch (error) { toast(error.message || 'Could not approve application.'); approve.disabled = false; }
    });
    actions.append(reject, approve); reviewPane.append(heading, grid, requestInfo, schedule, actions);
    card.append(person, reviewPane);
    return card;
  }

  async function loadApplications() {
    setNotice('');
    $('#applications').replaceChildren();
    const loading = document.createElement('div'); loading.className = 'empty'; loading.textContent = 'Loading applications…';
    $('#applications').append(loading);
    try {
      const result = await api('/functions/v1/review-washer-application');
      const list = $('#applications'); list.replaceChildren();
      if (!result.applications?.length) {
        const empty = document.createElement('div'); empty.className = 'empty'; empty.textContent = 'No applications are waiting for review.'; list.append(empty); return;
      }
      for (const application of result.applications) list.append(makeCard(application));
    } catch (error) {
      $('#applications').replaceChildren();
      setNotice(error.message || 'Could not load applications. Sign in again if your session expired.');
    }
  }

  $('#refresh').addEventListener('click', loadApplications);
  $('#signout').addEventListener('click', () => {
    accessToken = null; refreshToken = null;
    mfaForm.classList.add('hidden'); signinForm.classList.remove('hidden');
    show(config.url ? 'signin' : 'settings'); toast('Signed out.');
  });
})();
