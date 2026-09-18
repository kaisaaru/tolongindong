  <script>
    let currentAuthToken = localStorage.getItem('td_auth_token') || '';
    let currentTempToken = '';
    let lastResponseData = null;

    window.onload = () => {
      if (currentAuthToken) {
        setToken(currentAuthToken);
      }
    };

    function switchTab(tabId, triggerEl) {
      document.querySelectorAll('.tab-trigger').forEach(el => el.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));

      if (triggerEl) {
        triggerEl.classList.add('active');
      }
      document.getElementById(tabId).classList.add('active');
    }

    function setToken(token) {
      currentAuthToken = token;
      localStorage.setItem('td_auth_token', token);
      document.getElementById('active_token').value = token;

      const dot = document.getElementById('sessionDot');
      const status = document.getElementById('sessionStatus');

      if (token) {
        dot.classList.add('active');
        status.textContent = 'Active: ' + token.substring(0, 10) + '...';
      } else {
        dot.classList.remove('active');
        status.textContent = 'Unauthenticated';
      }
    }

    function randomizeRegisterData() {
      const rand = Math.floor(1000 + Math.random() * 9000);
      document.getElementById('reg_full_name').value = `User Test ${rand}`;
      document.getElementById('reg_email').value = `test_${rand}@example.com`;
      document.getElementById('reg_phone').value = `0812${rand}7890`;
    }

    function pushToast(title, desc, code = null) {
      const container = document.getElementById('toastContainer');
      const toast = document.createElement('div');
      toast.className = 'toast';
      toast.innerHTML = `
        <div class="toast-title">${title}</div>
        <div class="toast-desc">${desc}</div>
        ${code ? `<div class="toast-code">${code}</div>` : ''}
      `;
      container.appendChild(toast);
      setTimeout(() => {
        toast.remove();
      }, 7000);
    }

    function copyResponseJson() {
      if (!lastResponseData) return;
      navigator.clipboard.writeText(JSON.stringify(lastResponseData, null, 2));
      pushToast('Copied', 'JSON response disalin ke clipboard.');
    }

    async function callApi(method, endpoint, payload = null, useAuth = false) {
      const methodTag = document.getElementById('reqMethod');
      const urlBox = document.getElementById('reqUrl');
      const statusBadge = document.getElementById('statusBadge');
      const latencyBox = document.getElementById('reqLatency');
      const jsonViewer = document.getElementById('jsonOutput');

      const url = `/api/v1${endpoint}`;
      methodTag.textContent = method;
      methodTag.className = `method-tag method-${method}`;
      urlBox.textContent = url;
      latencyBox.textContent = '';
      statusBadge.className = 'badge';
      statusBadge.textContent = 'EXECUTING';
      jsonViewer.textContent = '// Memproses permintaan...';

      const headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      };

      if (useAuth && currentAuthToken) {
        headers['Authorization'] = `Bearer ${currentAuthToken}`;
      }

      const options = {
        method: method,
        headers: headers
      };

      if (payload && method !== 'GET') {
        options.body = JSON.stringify(payload);
      }

      const startTime = performance.now();

      try {
        const response = await fetch(url, options);
        const latency = Math.round(performance.now() - startTime);
        const data = await response.json();
        lastResponseData = data;

        latencyBox.textContent = `${latency}ms`;
        statusBadge.textContent = `${response.status} ${response.statusText}`;
        statusBadge.className = response.ok ? 'badge badge-success' : 'badge badge-destructive';
        jsonViewer.textContent = JSON.stringify(data, null, 2);

        return { ok: response.ok, status: response.status, data };
      } catch (err) {
        statusBadge.textContent = 'NETWORK ERR';
        statusBadge.className = 'badge badge-destructive';
        jsonViewer.textContent = JSON.stringify({ error: err.message }, null, 2);
        return { ok: false, error: err };
      }
    }

    async function submitRegister() {
      const payload = {
        full_name: document.getElementById('reg_full_name').value,
        email: document.getElementById('reg_email').value,
        phone_number: document.getElementById('reg_phone').value,
        password: document.getElementById('reg_password').value,
      };

      const res = await callApi('POST', '/auth/register', payload);

      if (res.ok && res.data.data) {
        document.getElementById('otp_phone').value = payload.phone_number;
        const code = res.data.data.debug_otp || '123456';
        document.getElementById('otp_code').value = code;

        pushToast('OTP Diterbitkan', `SMS dikirim ke ${payload.phone_number}`, code);
      }
    }

    async function submitVerifyOtp() {
      const payload = {
        phone_number: document.getElementById('otp_phone').value,
        otp_code: document.getElementById('otp_code').value,
      };

      if (currentTempToken) {
        payload.temp_token = currentTempToken;
      }

      const res = await callApi('POST', '/auth/verify-otp', payload);

      if (res.ok && res.data.data && res.data.data.token) {
        setToken(res.data.data.token);
        currentTempToken = '';
        document.getElementById('tempTokenContainer').style.display = 'none';

        const user = res.data.data.user;
        pushToast('Akun & Dompet Aktif', `${user.full_name} | Saldo: Rp ${user.wallet.available_balance}`);
      }
    }

    async function requestResendOtp() {
      const phone = document.getElementById('otp_phone').value;
      const res = await callApi('POST', '/auth/send-otp', { phone_number: phone, type: 'register' });
      if (res.ok && res.data.data && res.data.data.debug_otp) {
        document.getElementById('otp_code').value = res.data.data.debug_otp;
        pushToast('OTP Dikirim Ulang', `Terkirim ke ${phone}`, res.data.data.debug_otp);
      }
    }

    async function submitLogin() {
      const payload = {
        identifier: document.getElementById('login_identifier').value,
        password: document.getElementById('login_password').value,
      };

      const res = await callApi('POST', '/auth/login', payload);

      if (res.ok && res.data.data && res.data.data.token) {
        setToken(res.data.data.token);
        pushToast('Login Berhasil', `Sesi aktif untuk ${res.data.data.user.full_name}`);
      }
    }

    async function handleRealGoogleCredential(response) {
      const idToken = response.credential;
      const res = await callApi('POST', '/auth/google', { id_token: idToken });

      if (res.ok && res.data.data) {
        if (res.data.data.requires_phone_completion) {
          currentTempToken = res.data.data.temp_token;
          document.getElementById('otp_temp_token').value = currentTempToken;
          document.getElementById('tempTokenContainer').style.display = 'block';

          // Pindah ke tab verify OTP
          const verifyTrigger = document.querySelectorAll('.tab-trigger')[1];
          switchTab('tab-verify-otp', verifyTrigger);

          pushToast('Google Account Verified', `Lengkapi nomor telepon untuk ${res.data.data.profile.full_name}`);
        } else if (res.data.data.token) {
          setToken(res.data.data.token);
          pushToast('Google Login Success', `Selamat datang, ${res.data.data.user.full_name}`);
        }
      }
    }

    async function submitGoogleLogin(tokenChoice) {
      let idToken = tokenChoice || 'mock-google-token';
      const res = await callApi('POST', '/auth/google', { id_token: idToken });

      if (res.ok && res.data.data) {
        if (res.data.data.requires_phone_completion) {
          currentTempToken = res.data.data.temp_token;
          document.getElementById('otp_temp_token').value = currentTempToken;
          document.getElementById('tempTokenContainer').style.display = 'block';

          const verifyTrigger = document.querySelectorAll('.tab-trigger')[1];
          switchTab('tab-verify-otp', verifyTrigger);

          pushToast('Simulator: New User', 'Silakan isi nomor telepon untuk melengkapi pendaftaran.');
        } else if (res.data.data.token) {
          setToken(res.data.data.token);
          pushToast('Simulator: Authenticated', `Login berhasil untuk ${res.data.data.user.full_name}`);
        }
      }
    }

    async function fetchMe() {
      const res = await callApi('GET', '/auth/me', null, true);
      if (res.ok && res.data.data) {
        const u = res.data.data;
        pushToast('Profil Pengguna', `${u.full_name} (${u.email}) | Saldo: Rp ${u.wallet.available_balance}`);
      }
    }

    async function submitLogout() {
      const res = await callApi('POST', '/auth/logout', null, true);
      if (res.ok) {
        setToken('');
        pushToast('Session Terminated', 'Token Sanctum berhasil dicabut dari server.');
      }
    }
  </script>
