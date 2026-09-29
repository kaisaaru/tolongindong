  <script>
    let currentAuthToken = localStorage.getItem('td_auth_token') || '';
    let currentTempToken = '';
    let lastResponseData = null;
    let activeTriggerBtn = null;

    // Track clicked button for instant tactile loading feedback
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('button');
      if (btn && !btn.classList.contains('tab-trigger')) {
        activeTriggerBtn = btn;
      }
    }, true);

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
      const activeTokenInput = document.getElementById('active_token');
      if (activeTokenInput) activeTokenInput.value = token;

      const dot = document.getElementById('sessionDot');
      const status = document.getElementById('sessionStatus');

      if (status) {
        status.style.opacity = '0';
        setTimeout(() => {
          if (token) {
            dot.classList.add('active');
            status.textContent = 'Active: ' + token.substring(0, 10) + '...';
          } else {
            dot.classList.remove('active');
            status.textContent = 'Unauthenticated';
          }
          status.style.opacity = '1';
        }, 120);
      }
    }

    function clearSessionToken() {
      setToken('');
      pushToast('Session Cleared', 'Token bearer aktif telah dihapus.');
    }

    function randomizeRegisterData() {
      const rand = Math.floor(1000 + Math.random() * 9000);
      document.getElementById('reg_full_name').value = `User Test ${rand}`;
      document.getElementById('reg_email').value = `test_${rand}@example.com`;
      document.getElementById('reg_phone').value = `0812${rand}7890`;
    }

    function fillAdminLogin() {
      document.getElementById('login_identifier').value = 'admin@admin.com';
      document.getElementById('login_password').value = 'password';
      pushToast('Admin Account Filled', 'Kredensial admin@admin.com berhasil diisi. Klik Send POST /login untuk masuk.');
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
        toast.classList.add('toast-exit');
        setTimeout(() => {
          toast.remove();
        }, 250);
      }, 5000);
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

      const btn = activeTriggerBtn;
      let originalBtnHtml = '';
      if (btn && !btn.classList.contains('is-loading')) {
        originalBtnHtml = btn.innerHTML;
        btn.classList.add('is-loading');
        btn.innerHTML = `<span class="btn-spinner"></span>` + originalBtnHtml;
      }

      const url = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
      methodTag.textContent = method;
      methodTag.className = `method-badge method-${method}`;
      urlBox.textContent = url;
      latencyBox.textContent = '';
      statusBadge.className = 'status-badge';
      statusBadge.textContent = 'EXECUTING';
      jsonViewer.classList.add('is-loading');
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
        statusBadge.className = response.ok ? 'status-badge status-2xx' : 'status-badge status-4xx';
        jsonViewer.textContent = JSON.stringify(data, null, 2);

        return { ok: response.ok, status: response.status, data };
      } catch (err) {
        statusBadge.textContent = 'NETWORK ERR';
        statusBadge.className = 'status-badge status-5xx';
        jsonViewer.textContent = JSON.stringify({ error: err.message }, null, 2);
        return { ok: false, error: err };
      } finally {
        if (btn && originalBtnHtml) {
          btn.innerHTML = originalBtnHtml;
          btn.classList.remove('is-loading');
        }
        jsonViewer.classList.remove('is-loading');
        activeTriggerBtn = null;
      }
    }

    async function submitRegister() {
      const payload = {
        full_name: document.getElementById('reg_full_name').value,
        email: document.getElementById('reg_email').value,
        phone_number: document.getElementById('reg_phone').value,
        password: document.getElementById('reg_password').value,
      };

      const res = await callApi('POST', '/register', payload);

      if (res.ok && res.data.data) {
        lastRegisteredPhone = res.data.data.phone_number;
        document.getElementById('otp_phone').value = lastRegisteredPhone;

        if (res.data.data.debug_otp) {
          document.getElementById('otp_code').value = res.data.data.debug_otp;
        }

        const verifyTrigger = document.querySelectorAll('.tab-trigger')[1];
        switchTab('tab-verify-otp', verifyTrigger);

        pushToast(
          'Pendaftaran Berhasil',
          `Kode OTP 6-digit dibuat untuk nomor ${lastRegisteredPhone}`,
          res.data.data.debug_otp ? `DEBUG OTP: ${res.data.data.debug_otp}` : null
        );
      }
    }

    async function submitVerifyOtp() {
      const payload = {
        phone_number: document.getElementById('otp_phone').value,
        otp_code: document.getElementById('otp_code').value,
        temp_token: document.getElementById('otp_temp_token').value || null,
      };

      const res = await callApi('POST', '/verify-otp', payload);

      if (res.ok && res.data.data?.token) {
        setToken(res.data.data.token);
        pushToast('Akun Terverifikasi', `Selamat datang, ${res.data.data.user.full_name}! TD-Wallet aktif.`);
      }
    }

    async function resendOtp() {
      const phone = document.getElementById('otp_phone').value;
      if (!phone) {
        pushToast('Input Error', 'Isi nomor telepon terlebih dahulu');
        return;
      }

      const res = await callApi('POST', '/send-otp', { phone_number: phone, type: 'register' });
      if (res.ok && res.data.data?.debug_otp) {
        document.getElementById('otp_code').value = res.data.data.debug_otp;
        pushToast('OTP Dikirim Ulang', `DEBUG OTP: ${res.data.data.debug_otp}`);
      }
    }

    async function submitLogin() {
      const payload = {
        identifier: document.getElementById('login_identifier').value,
        password: document.getElementById('login_password').value,
      };

      const res = await callApi('POST', '/login', payload);

      if (res.ok && res.data.data?.token) {
        setToken(res.data.data.token);
        pushToast('Login Berhasil', `Sesi aktif untuk ${res.data.data.user.full_name}`);
      } else if (!res.ok) {
        pushToast('Login Ditolak', res.data?.message || 'Nomor telepon/email atau kata sandi tidak cocok.');
      }
    }

    async function handleGoogleCredentialResponse(response) {
      const idToken = response.credential;
      const res = await callApi('POST', '/google', { id_token: idToken });

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
      const res = await callApi('POST', '/google', { id_token: idToken });

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
      const res = await callApi('GET', '/me', null, true);
      if (res.ok && res.data.data) {
        const u = res.data.data;
        pushToast('Profil Pengguna', `${u.full_name} (${u.email}) | Saldo: Rp ${u.wallet.available_balance}`);
      }
    }

    async function submitLogout() {
      const res = await callApi('POST', '/logout', null, true);
      if (res.ok) {
        setToken('');
        pushToast('Session Terminated', 'Token Sanctum berhasil dicabut dari server.');
      }
    }

    async function callApiForm(method, endpoint, formData, useAuth = false) {
      const methodTag = document.getElementById('reqMethod');
      const urlBox = document.getElementById('reqUrl');
      const statusBadge = document.getElementById('statusBadge');
      const latencyBox = document.getElementById('reqLatency');
      const jsonViewer = document.getElementById('jsonOutput');

      const btn = activeTriggerBtn;
      let originalBtnHtml = '';
      if (btn && !btn.classList.contains('is-loading')) {
        originalBtnHtml = btn.innerHTML;
        btn.classList.add('is-loading');
        btn.innerHTML = `<span class="btn-spinner"></span>` + originalBtnHtml;
      }

      const url = endpoint.startsWith('/') ? endpoint : `/${endpoint}`;
      methodTag.textContent = method;
      methodTag.className = `method-badge method-${method}`;
      urlBox.textContent = url;
      latencyBox.textContent = '';
      statusBadge.className = 'status-badge';
      statusBadge.textContent = 'EXECUTING';
      jsonViewer.classList.add('is-loading');
      jsonViewer.textContent = '// Mengunggah berkas multipart...';

      const headers = {
        'Accept': 'application/json',
      };

      if (useAuth && currentAuthToken) {
        headers['Authorization'] = `Bearer ${currentAuthToken}`;
      }

      const startTime = performance.now();

      try {
        const response = await fetch(url, {
          method: method,
          headers: headers,
          body: formData
        });
        const latency = Math.round(performance.now() - startTime);
        const data = await response.json();
        lastResponseData = data;

        latencyBox.textContent = `${latency}ms`;
        statusBadge.textContent = `${response.status} ${response.statusText}`;
        statusBadge.className = response.ok ? 'status-badge status-2xx' : 'status-badge status-4xx';
        jsonViewer.textContent = JSON.stringify(data, null, 2);

        return { ok: response.ok, status: response.status, data };
      } catch (err) {
        statusBadge.textContent = 'NETWORK ERR';
        statusBadge.className = 'status-badge status-5xx';
        jsonViewer.textContent = JSON.stringify({ error: err.message }, null, 2);
        return { ok: false, error: err };
      } finally {
        if (btn && originalBtnHtml) {
          btn.innerHTML = originalBtnHtml;
          btn.classList.remove('is-loading');
        }
        jsonViewer.classList.remove('is-loading');
        activeTriggerBtn = null;
      }
    }

    async function submitHelperRegister() {
      if (!currentAuthToken) {
        pushToast('Auth Required', 'Silakan login terlebih dahulu untuk mendaftar sebagai helper.');
        return;
      }

      const formData = new FormData();
      const catCheckboxes = document.querySelectorAll('input[name="helper_cats"]:checked');
      catCheckboxes.forEach(cb => {
        formData.append('category_ids[]', cb.value);
      });

      formData.append('hourly_rate', document.getElementById('helper_hourly_rate').value);
      formData.append('max_advance_limit', document.getElementById('helper_max_advance').value);

      const ktpInput = document.getElementById('helper_ktp_file');
      const selfieInput = document.getElementById('helper_selfie_file');

      if (ktpInput.files.length > 0) {
        formData.append('id_card_photo', ktpInput.files[0]);
      } else {
        // Fallback dummy file untuk kemudahan testing jika tidak memilih file
        formData.append('id_card_photo', new File(['dummy_ktp_content'], 'ktp.jpg', { type: 'image/jpeg' }));
      }

      if (selfieInput.files.length > 0) {
        formData.append('selfie_photo', selfieInput.files[0]);
      } else {
        // Fallback dummy file untuk kemudahan testing jika tidak memilih file
        formData.append('selfie_photo', new File(['dummy_selfie_content'], 'selfie.jpg', { type: 'image/jpeg' }));
      }

      const res = await callApiForm('POST', '/helper/register', formData, true);
      if (res.ok) {
        pushToast('Pendaftaran Helper Berhasil', 'Berkas identitas berhasil dikirim. Menunggu peninjauan admin.');
        if (res.data.data?.verification_id) {
          document.getElementById('admin_verif_id').value = res.data.data.verification_id;
        }
      } else {
        pushToast('Gagal Daftar Helper', res.data?.message || 'Periksa kelengkapan berkas.');
      }
    }

    async function fetchHelperStatus() {
      const res = await callApi('GET', '/helper/status', null, true);
      if (res.ok && res.data.data) {
        const d = res.data.data;
        pushToast('Status Helper', `Status: ${d.verification_status.toUpperCase()} | Helper Aktif: ${d.is_verified_helper ? 'YA' : 'TIDAK'}`);
      }
    }

    async function fetchAdminVerifications() {
      const res = await callApi('GET', '/admin/verifications', null, true);
      if (res.ok && res.data.data) {
        const list = res.data.data.data || [];
        pushToast('Data Verifikasi', `Ditemukan ${list.length} tiket verifikasi.`);
        if (list.length > 0 && !document.getElementById('admin_verif_id').value) {
          document.getElementById('admin_verif_id').value = list[0].id;
        }
      }
    }

    async function submitAdminApprove() {
      const id = document.getElementById('admin_verif_id').value;
      if (!id) {
        pushToast('Input Error', 'Masukkan ID tiket verifikasi yang ingin disetujui.');
        return;
      }
      const res = await callApi('POST', `/admin/verifications/${id}/approve`, null, true);
      if (res.ok) {
        pushToast('Helper Disetujui', `Pengajuan #${id} disetujui. Akun helper aktif.`);
      }
    }

    async function submitAdminReject() {
      const id = document.getElementById('admin_verif_id').value;
      const reason = document.getElementById('admin_reject_reason').value;
      if (!id) {
        pushToast('Input Error', 'Masukkan ID tiket verifikasi yang ingin ditolak.');
        return;
      }
      const res = await callApi('POST', `/admin/verifications/${id}/reject`, { rejection_reason: reason }, true);
      if (res.ok) {
        pushToast('Helper Ditolak', `Pengajuan #${id} ditolak dengan alasan: ${reason}`);
      }
    }

    async function fetchClientDashboard() {
      const res = await callApi('GET', '/client/dashboard', null, true);
      if (res.ok && res.data.data) {
        const d = res.data.data;
        pushToast('Client Hub Loaded', `Saldo Wallet: Rp ${d.client?.wallet?.available_balance || 0} | Helper Aktif di Sekitar: ${d.nearby_helpers_count || 0}`);
      }
    }

    async function fetchHelperDashboard() {
      const res = await callApi('GET', '/helper/dashboard', null, true);
      if (res.ok && res.data.data) {
        const d = res.data.data;
        pushToast('Helper Hub Loaded', `Status: ${d.profile?.verification_status || 'N/A'} | Total Order Selesai: ${d.stats?.completed_orders || 0}`);
      }
    }

    async function fetchAdminDashboard() {
      const res = await callApi('GET', '/admin/dashboard', null, true);
      if (res.ok && res.data.data) {
        const d = res.data.data;
        pushToast('Admin Portal Loaded', `Total User: ${d.overview?.total_users || 0} | Pending Verifikasi: ${d.verifications?.pending_count || 0}`);
      }
    }

    async function fetchServiceCategories() {
      const res = await callApi('GET', '/service-categories', null, false);
      if (res.ok && res.data.data) {
        const list = res.data.data || [];
        pushToast('Katalog Kategori', `Memuat ${list.length} kategori layanan.`);
      }
    }

    async function submitForgotPassword() {
      const phone = document.getElementById('pw_forgot_phone').value;
      if (!phone) {
        pushToast('Input Error', 'Masukkan nomor telepon terdaftar.');
        return;
      }

      const res = await callApi('POST', '/password/forgot', { phone_number: phone });
      if (res.ok) {
        pushToast('OTP Terkirim', 'Kode pemulihan kata sandi telah dikirim.');
        if (res.data.data?.debug_otp) {
          document.getElementById('pw_reset_otp').value = res.data.data.debug_otp;
        }
      } else {
        pushToast('Permintaan Gagal', res.data?.message || 'Nomor tidak ditemukan.');
      }
    }

    async function submitResetPassword() {
      const payload = {
        phone_number: document.getElementById('pw_forgot_phone').value,
        otp_code: document.getElementById('pw_reset_otp').value,
        new_password: document.getElementById('pw_reset_new_password').value,
      };

      const res = await callApi('POST', '/password/reset', payload);
      if (res.ok) {
        pushToast('Kata Sandi Diperbarui', res.data?.message || 'Kata sandi berhasil disimpan. Silakan login.');
        // Beralih ke tab login
        const loginTrigger = document.querySelectorAll('.tab-trigger')[2];
        document.getElementById('login_identifier').value = payload.phone_number;
        document.getElementById('login_password').value = payload.new_password;
        switchTab('tab-login', loginTrigger);
      } else {
        pushToast('Reset Gagal', res.data?.message || 'Periksa kode OTP atau panjang password.');
      }
    }

    async function submitChangePassword() {
      const payload = {
        current_password: document.getElementById('pw_change_current').value || null,
        new_password: document.getElementById('pw_change_new').value,
      };

      const res = await callApi('POST', '/password/change', payload, true);
      if (res.ok) {
        pushToast('Berhasil Diubah', res.data?.message || 'Kata sandi berhasil disimpan.');
        document.getElementById('pw_change_current').value = '';
      } else {
        pushToast('Gagal Ubah Sandi', res.data?.message || 'Periksa kecocokan kata sandi lama.');
      }
    }
  </script>

