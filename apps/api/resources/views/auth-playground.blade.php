<!DOCTYPE html>
<html lang="id" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TolonginDong — API Console</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&family=Geist+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <script src="https://accounts.google.com/gsi/client" async defer></script>
  @include('partials.playground-styles')
</head>
<body>

  <!-- STICKY NAVBAR -->
  <header class="navbar">
    <div class="navbar-container">
      <div class="nav-brand">
        <div class="nav-logo-icon">TD</div>
        <div class="nav-title">
          <span>TolonginDong</span>
          <span class="nav-badge">REST API v1</span>
        </div>
      </div>

      <div class="nav-actions">
        <div class="session-status-badge">
          <div class="status-dot" id="sessionDot"></div>
          <span id="sessionStatus">Unauthenticated</span>
        </div>
        <button class="btn btn-secondary btn-sm" onclick="clearSessionToken()" title="Hapus token sesi saat ini">Clear Token</button>
      </div>
    </div>
  </header>

  <!-- SUBHEADER STATUS BAR -->
  <div class="subheader-bar">
    <div class="subheader-container">
      <div class="meta-chips">
        <div class="meta-chip">
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2 1.5 3 3.5 3h9c2 0 3.5-1 3.5-3V7c0-2-1.5-3-3.5-3h-9C5.5 4 4 5 4 7zM9 9h6M9 13h6M9 17h4"></path></svg>
          <span>PostgreSQL Supabase (UUID v4)</span>
        </div>
        <div class="meta-chip">
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 00-9.78 2.096A4.001 4.001 0 003 15z"></path></svg>
          <span>Cloudflare R2 KYC Vault</span>
        </div>
        <div class="meta-chip">
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>
          <span>Laravel Sanctum Auth</span>
        </div>
      </div>
      <div class="meta-chip" style="font-family: var(--font-mono); font-size: 11px;">
        Environment: Local Dev
      </div>
    </div>
  </div>

  <!-- WORKSPACE 2-COLUMN LAYOUT -->
  <main class="main-shell">
    <div class="workspace-grid">

      <!-- LEFT: REQUEST CONTROLLER -->
      <div class="card">
        <div class="card-header">
          <h2 class="card-title">Endpoint Request Builder</h2>
          <p class="card-description">Uji langsung seluruh endpoint REST API TolonginDong dengan payload interaktif.</p>
        </div>

        <div class="card-content">
          <!-- GROUPED TAB NAVIGATION -->
          <div class="nav-groups">
            <!-- GROUP 1: AUTH -->
            <div class="tabs-list">
              <span class="tabs-group-label">Auth</span>
              <button class="tab-trigger active" onclick="switchTab('tab-register', this)">Register</button>
              <button class="tab-trigger" onclick="switchTab('tab-verify-otp', this)">Verify OTP</button>
              <button class="tab-trigger" onclick="switchTab('tab-login', this)">Login</button>
              <button class="tab-trigger" onclick="switchTab('tab-google', this)">Google</button>
              <button class="tab-trigger" onclick="switchTab('tab-password', this)">Password</button>
              <button class="tab-trigger" onclick="switchTab('tab-session', this)">Session / Me</button>
            </div>

            <!-- GROUP 2: ROLES -->
            <div class="tabs-list">
              <span class="tabs-group-label">Modules</span>
              <button class="tab-trigger" onclick="switchTab('tab-client', this)">Client Hub</button>
              <button class="tab-trigger" onclick="switchTab('tab-helper', this)">Helper Hub</button>
              <button class="tab-trigger" onclick="switchTab('tab-admin', this)">Admin Portal</button>
              <button class="tab-trigger" onclick="switchTab('tab-categories', this)">Categories</button>
            </div>
          </div>

          <!-- 1. TAB: REGISTER FORM -->
          <div class="tab-content active" id="tab-register">
            <div class="form-item">
              <label class="form-label" for="reg_full_name">Nama Lengkap</label>
              <input type="text" id="reg_full_name" value="Budi Santoso" placeholder="Masukkan nama lengkap">
            </div>
            <div class="form-row">
              <div class="form-item">
                <label class="form-label" for="reg_email">Email</label>
                <input type="email" id="reg_email" value="budi.santoso@example.com" placeholder="nama@email.com">
              </div>
              <div class="form-item">
                <label class="form-label" for="reg_phone">Nomor Telepon</label>
                <input type="text" id="reg_phone" value="081234567890" placeholder="08xxxxxxxxxx">
              </div>
            </div>
            <div class="form-item">
              <label class="form-label" for="reg_password">
                <span>Kata Sandi</span>
                <span class="form-hint">Min. 8 karakter (FR-AUTH-001)</span>
              </label>
              <input type="password" id="reg_password" value="Rahasia123!">
            </div>
            <div class="button-stack">
              <button class="btn btn-secondary" onclick="randomizeRegisterData()">Generate Random Data</button>
              <button class="btn btn-primary" style="flex: 1;" onclick="submitRegister()">Send POST /register</button>
            </div>
          </div>

          <!-- 2. TAB: VERIFY OTP -->
          <div class="tab-content" id="tab-verify-otp">
            <div class="form-item">
              <label class="form-label" for="otp_phone">Nomor Telepon</label>
              <input type="text" id="otp_phone" value="081234567890" placeholder="Nomor telepon yang didaftarkan">
            </div>
            <div class="form-item">
              <label class="form-label" for="otp_code">
                <span>Kode OTP 6-Digit</span>
                <span class="form-hint">Masa berlaku 300 detik</span>
              </label>
              <input type="text" id="otp_code" value="123456" maxlength="6" style="font-family: var(--font-mono); letter-spacing: 2px;">
            </div>
            <div class="form-item" id="tempTokenContainer" style="display: none;">
              <label class="form-label" for="otp_temp_token">Google Encrypted Temp Token</label>
              <input type="text" id="otp_temp_token" readonly style="font-family: var(--font-mono); font-size: 11px; color: var(--muted-foreground);">
            </div>
            <div class="button-stack">
              <button class="btn btn-secondary" onclick="resendOtp()">Resend Code</button>
              <button class="btn btn-emerald" style="flex: 1;" onclick="submitVerifyOtp()">Verify & Provision Wallet</button>
            </div>
          </div>

          <!-- 3. TAB: LOGIN FORM -->
          <div class="tab-content" id="tab-login">
            <div class="form-item">
              <label class="form-label" for="login_identifier">Nomor Telepon / Email</label>
              <input type="text" id="login_identifier" value="budi.santoso@example.com" placeholder="Email atau nomor WhatsApp">
            </div>
            <div class="form-item">
              <label class="form-label" for="login_password">Kata Sandi</label>
              <input type="password" id="login_password" value="Rahasia123!">
            </div>
            <div class="button-stack">
              <button class="btn btn-secondary" onclick="fillAdminLogin()">Isi Akun Admin</button>
              <button class="btn btn-primary" style="flex: 1;" onclick="submitLogin()">Send POST /login</button>
            </div>
          </div>

          <!-- 4. TAB: GOOGLE SIGN-IN -->
          <div class="tab-content" id="tab-google">
            <p class="card-description" style="margin-bottom: 14px;">
              Menguji integrasi OAuth 2.0 Google dengan ID Token asli atau mock simulator lokal.
            </p>
            <div style="margin-bottom: 16px;">
              <div id="g_id_onload"
                   data-client_id="{{ config('services.google.client_id') }}"
                   data-callback="handleGoogleCredentialResponse"
                   data-auto_prompt="false">
              </div>
              <div class="g_id_signin" data-type="standard" data-shape="rectangular" data-theme="filled_black" data-text="signin_with" data-size="large" data-logo_alignment="left"></div>
            </div>
            <div class="button-stack">
              <button class="btn btn-secondary" style="flex: 1;" onclick="submitGoogleLogin('mock-google-new')">Mock: Akun Baru</button>
              <button class="btn btn-secondary" style="flex: 1;" onclick="submitGoogleLogin('mock-google-returning')">Mock: Akun Terdaftar</button>
            </div>
          </div>

          <!-- 5. TAB: SESSION / ME -->
          <div class="tab-content" id="tab-session">
            <div class="form-item">
              <label class="form-label" for="active_token">Active Bearer Token (Sanctum)</label>
              <input type="text" id="active_token" placeholder="Token otomatis terisi setelah login" style="font-family: var(--font-mono); font-size: 11.5px;">
            </div>
            <div class="button-stack">
              <button class="btn btn-primary" style="flex: 1;" onclick="fetchMe()">GET /me</button>
              <button class="btn btn-destructive" onclick="submitLogout()">POST /logout</button>
            </div>
          </div>

          <!-- 6. TAB: PASSWORD RECOVERY & CHANGE -->
          <div class="tab-content" id="tab-password">
            <p class="card-description" style="margin-bottom: 14px;">
              Pemulihan kata sandi via OTP (FR-AUTH-006) atau ganti kata sandi langsung di dalam sesi aplikasi.
            </p>

            <div class="section-title">
              <span>1. Lupa Sandi / Akun Google via OTP (Publik)</span>
            </div>
            <div class="form-item">
              <label class="form-label" for="pw_forgot_phone">Nomor Telepon Terdaftar</label>
              <div style="display: flex; gap: 8px;">
                <input type="text" id="pw_forgot_phone" value="081299990001" placeholder="08xxxxxxxxxx">
                <button class="btn btn-secondary" style="white-space: nowrap;" onclick="submitForgotPassword()">Kirim OTP</button>
              </div>
            </div>
            <div class="form-row">
              <div class="form-item">
                <label class="form-label" for="pw_reset_otp">Kode OTP 6-Digit</label>
                <input type="text" id="pw_reset_otp" placeholder="123456" maxlength="6" style="font-family: var(--font-mono); letter-spacing: 2px;">
              </div>
              <div class="form-item">
                <label class="form-label" for="pw_reset_new_password">Kata Sandi Baru</label>
                <input type="password" id="pw_reset_new_password" value="PasswordBaru123!">
              </div>
            </div>
            <div class="button-stack" style="margin-top: 6px;">
              <button class="btn btn-primary" style="width: 100%;" onclick="submitResetPassword()">Send POST /password/reset</button>
            </div>

            <div class="separator"></div>

            <div class="section-title">
              <span>2. Ubah / Pasang Sandi Sesi Login (auth:sanctum)</span>
            </div>
            <div class="form-row">
              <div class="form-item">
                <label class="form-label" for="pw_change_current">
                  <span>Kata Sandi Saat Ini</span>
                  <span class="form-hint">(Kosongkan jika Google)</span>
                </label>
                <input type="password" id="pw_change_current" placeholder="Password lama">
              </div>
              <div class="form-item">
                <label class="form-label" for="pw_change_new">Kata Sandi Baru</label>
                <input type="password" id="pw_change_new" value="GantiSandiBaru123!">
              </div>
            </div>
            <div class="button-stack" style="margin-top: 6px;">
              <button class="btn btn-emerald" style="width: 100%;" onclick="submitChangePassword()">Send POST /password/change</button>
            </div>
          </div>

          <!-- 7. TAB: CLIENT HUB -->
          <div class="tab-content" id="tab-client">
            <p class="card-description" style="margin-bottom: 14px;">
              Ringkasan profil pemesan tugas, saldo TD-Wallet, dan katalog helper di sekitar pemesan.
            </p>
            <div class="button-stack">
              <button class="btn btn-primary" style="flex: 1;" onclick="fetchClientDashboard()">GET /client/dashboard</button>
            </div>
          </div>

          <!-- 8. TAB: HELPER HUB -->
          <div class="tab-content" id="tab-helper">
            <p class="card-description" style="margin-bottom: 14px;">
              Registrasi mitra Helper, berkas KYC (KTP & swafoto) ke R2, dan cek status tiket verifikasi.
            </p>

            <div class="form-item">
              <label class="form-label">Pilih Kategori Keahlian (1 - 6)</label>
              <div class="category-grid">
                <label class="category-chip">
                  <input type="checkbox" name="helper_cats" value="1" checked>
                  <span class="category-chip-label">Food Run</span>
                </label>
                <label class="category-chip">
                  <input type="checkbox" name="helper_cats" value="2" checked>
                  <span class="category-chip-label">Delivery</span>
                </label>
                <label class="category-chip">
                  <input type="checkbox" name="helper_cats" value="3">
                  <span class="category-chip-label">Moving</span>
                </label>
                <label class="category-chip">
                  <input type="checkbox" name="helper_cats" value="4">
                  <span class="category-chip-label">Personal</span>
                </label>
                <label class="category-chip">
                  <input type="checkbox" name="helper_cats" value="5">
                  <span class="category-chip-label">Household</span>
                </label>
                <label class="category-chip">
                  <input type="checkbox" name="helper_cats" value="6">
                  <span class="category-chip-label">Laundry</span>
                </label>
              </div>
            </div>

            <div class="form-row">
              <div class="form-item">
                <label class="form-label" for="helper_hourly_rate">Tarif per Jam (Rp)</label>
                <input type="number" id="helper_hourly_rate" value="25000">
              </div>
              <div class="form-item">
                <label class="form-label" for="helper_max_advance">Batas Talangan (Rp)</label>
                <input type="number" id="helper_max_advance" value="100000">
              </div>
            </div>

            <div class="form-row">
              <div class="form-item">
                <label class="form-label" for="helper_ktp_file">Foto e-KTP (Private R2)</label>
                <input type="file" id="helper_ktp_file" accept="image/*">
              </div>
              <div class="form-item">
                <label class="form-label" for="helper_selfie_file">Swafoto + e-KTP (Private R2)</label>
                <input type="file" id="helper_selfie_file" accept="image/*">
              </div>
            </div>

            <div class="button-stack">
              <button class="btn btn-primary" style="flex: 1;" onclick="submitHelperRegister()">POST /helper/register</button>
              <button class="btn btn-secondary" onclick="fetchHelperStatus()">GET /helper/status</button>
              <button class="btn btn-secondary" onclick="fetchHelperDashboard()">GET /helper/dashboard</button>
            </div>
          </div>

          <!-- 9. TAB: ADMIN PORTAL -->
          <div class="tab-content" id="tab-admin">
            <p class="card-description" style="margin-bottom: 14px;">
              Peninjauan berkas KYC dan approval pendaftaran mitra helper.
              <span style="color: #fafafa; font-weight: 600;">(Admin: admin@admin.com &bull; password)</span>
            </p>

            <div class="form-row">
              <div class="form-item">
                <label class="form-label" for="admin_verif_id">ID Tiket Verifikasi (UUID)</label>
                <input type="text" id="admin_verif_id" placeholder="Contoh: 9b1deb4d-...">
              </div>
              <div class="form-item">
                <label class="form-label" for="admin_reject_reason">Alasan Penolakan</label>
                <input type="text" id="admin_reject_reason" value="Foto KTP silau dan NIK tidak terbaca jelas">
              </div>
            </div>

            <div class="button-stack">
              <button class="btn btn-emerald" style="flex: 1;" onclick="submitAdminApprove()">Approve Helper</button>
              <button class="btn btn-destructive" style="flex: 1;" onclick="submitAdminReject()">Reject Helper</button>
            </div>

            <div class="button-stack" style="margin-top: 8px;">
              <button class="btn btn-secondary" style="flex: 1;" onclick="fetchAdminDashboard()">GET /admin/dashboard</button>
              <button class="btn btn-secondary" style="flex: 1;" onclick="fetchAdminVerifications()">GET /admin/verifications</button>
            </div>
          </div>

          <!-- 10. TAB: SERVICE CATEGORIES -->
          <div class="tab-content" id="tab-categories">
            <p class="card-description" style="margin-bottom: 14px;">
              Mengambil daftar 6 kategori layanan resmi TolonginDong dari database PostgreSQL (Publik).
            </p>
            <div class="button-stack">
              <button class="btn btn-primary" style="width: 100%;" onclick="fetchServiceCategories()">GET /service-categories</button>
            </div>
          </div>

        </div>
      </div>

      <!-- RIGHT: LIVE API RESPONSE INSPECTOR -->
      <div class="inspector-card">
        <div class="inspector-header">
          <div>
            <div style="font-size: 13.5px; font-weight: 600; color: var(--foreground);">Live API Inspector</div>
            <div style="font-size: 11.5px; color: var(--muted-foreground);">Real-time HTTP Request & Response Envelope</div>
          </div>
          <div id="statusBadge" class="status-badge">READY</div>
        </div>

        <div class="endpoint-strip">
          <span class="method-badge method-GET" id="reqMethod">IDLE</span>
          <span id="reqUrl" style="color: var(--muted-foreground);">Menunggu panggilan API...</span>
          <span id="reqLatency" style="margin-left: auto; color: var(--muted-foreground); font-size: 11px;"></span>
        </div>

        <div class="viewport-container">
          <div class="viewport-toolbar">
            <span class="viewport-label">Response Envelope</span>
            <button class="btn btn-secondary btn-sm" onclick="copyResponseJson()">Copy JSON</button>
          </div>
          <pre class="json-viewport" id="jsonOutput">// Jalankan salah satu permintaan API di panel kiri untuk melihat respons JSON...</pre>
        </div>
      </div>

    </div>
  </main>

  <!-- TOAST CONTAINER -->
  <div class="toast-container" id="toastContainer"></div>

  @include('partials.playground-scripts')
</body>
</html>
