<!DOCTYPE html>
<html lang="id" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TolonginDong — API Console</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Geist:wght@300;400;500;600;700&family=Geist+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <script src="https://accounts.google.com/gsi/client" async defer></script>
  @include('partials.playground-styles')
</head>
<body>

  <div class="app-shell">
    <header>
      <div class="brand">
        <div class="brand-title">
          <span>TolonginDong</span>
          <span style="color: var(--muted);">/</span>
          <span style="color: var(--muted-foreground); font-weight: 400;">Auth API Testing Console</span>
          <span class="badge">v1.0</span>
        </div>
      </div>

      <div class="header-actions">
        <div class="session-pill">
          <div class="status-dot" id="sessionDot"></div>
          <span id="sessionStatus">Unauthenticated</span>
        </div>
      </div>
    </header>

    <div class="workspace-grid">
      <!-- LEFT: INTERACTIVE CONTROLLER TABS -->
      <div class="card">
        <div class="card-header">
          <h2 class="card-title">Endpoint Request Builder</h2>
          <p class="card-description">Pilih modul untuk menguji kontrak API otentikasi TolonginDong.</p>
        </div>

        <div class="tabs-list">
          <button class="tab-trigger active" onclick="switchTab('tab-register', this)">Register</button>
          <button class="tab-trigger" onclick="switchTab('tab-verify-otp', this)">Verify OTP</button>
          <button class="tab-trigger" onclick="switchTab('tab-login', this)">Login</button>
          <button class="tab-trigger" onclick="switchTab('tab-google', this)">Google Sign-In</button>
          <button class="tab-trigger" onclick="switchTab('tab-session', this)">Session / Me</button>
        </div>

        <!-- 1. REGISTER FORM -->
        <div class="tab-content active" id="tab-register">
          <div class="form-item">
            <label>Nama Lengkap</label>
            <input type="text" id="reg_full_name" value="Budi Santoso">
          </div>
          <div class="form-row">
            <div class="form-item">
              <label>Email</label>
              <input type="email" id="reg_email" value="budi.santoso@example.com">
            </div>
            <div class="form-item">
              <label>Nomor Telepon</label>
              <input type="text" id="reg_phone" value="081234567890">
            </div>
          </div>
          <div class="form-item">
            <label>Kata Sandi</label>
            <input type="password" id="reg_password" value="Rahasia123!">
            <p class="form-description">Minimal 8 karakter sesuai spesifikasi FR-AUTH-001.</p>
          </div>
          <div class="button-stack">
            <button class="btn btn-secondary" onclick="randomizeRegisterData()">Generate Random Data</button>
            <button class="btn btn-primary" style="flex: 1;" onclick="submitRegister()">Send POST /register</button>
          </div>
        </div>

        <!-- 2. VERIFY OTP FORM -->
        <div class="tab-content" id="tab-verify-otp">
          <div class="form-item">
            <label>Nomor Telepon</label>
            <input type="text" id="otp_phone" value="081234567890">
          </div>
          <div class="form-item">
            <label>Kode OTP (6 Digit)</label>
            <input type="text" id="otp_code" value="123456" maxlength="6" style="font-family: 'Geist Mono', monospace; font-size: 16px; letter-spacing: 2px;">
            <p class="form-description">Kode berlaku selama 300 detik (FR-AUTH-002).</p>
          </div>
          <div class="form-item" id="tempTokenContainer" style="display: none;">
            <label>Encrypted Google Registration Token</label>
            <input type="text" id="otp_temp_token" readonly style="font-family: 'Geist Mono', monospace; font-size: 11px; color: var(--muted);">
          </div>
          <div class="button-stack">
            <button class="btn btn-secondary" onclick="requestResendOtp()">Resend Code</button>
            <button class="btn btn-primary" style="flex: 1;" onclick="submitVerifyOtp()">Verify & Provision Wallet</button>
          </div>
        </div>

        <!-- 3. LOGIN FORM -->
        <div class="tab-content" id="tab-login">
          <div class="form-item">
            <label>Identifier (Email atau Nomor Telepon)</label>
            <input type="text" id="login_identifier" value="budi.santoso@example.com">
          </div>
          <div class="form-item">
            <label>Kata Sandi</label>
            <input type="password" id="login_password" value="Rahasia123!">
            <p class="form-description">Rate limiter: 5x gagal berturut-turut mengunci akun selama 900 detik (FR-AUTH-005).</p>
          </div>
          <div class="button-stack">
            <button class="btn btn-primary btn-full" onclick="submitLogin()">Authenticate (POST /login)</button>
          </div>
        </div>

        <!-- 4. GOOGLE SIGN-IN -->
        <div class="tab-content" id="tab-google">
          <div style="border: 1px solid var(--border); background: #121215; border-radius: var(--radius); padding: 20px; text-align: center; margin-bottom: 20px;">
            <div style="font-size: 13px; font-weight: 500; color: var(--foreground); margin-bottom: 4px;">Google OAuth 2.0 Web Client</div>
            <div style="font-size: 12px; color: var(--muted-foreground); margin-bottom: 16px;">
              Terhubung dengan Client ID: <code style="font-family: 'Geist Mono', monospace;">{{ substr(config('services.google.client_id'), 0, 16) }}...</code>
            </div>

            <div id="g_id_onload"
                 data-client_id="{{ config('services.google.client_id') }}"
                 data-callback="handleRealGoogleCredential"
                 data-auto_prompt="false">
            </div>
            <div style="display: flex; justify-content: center;">
              <div class="g_id_signin" 
                   data-type="standard" 
                   data-size="large" 
                   data-theme="outline" 
                   data-text="signin_with" 
                   data-shape="rectangular" 
                   data-logo_alignment="left">
              </div>
            </div>
          </div>

          <div style="font-size: 12px; font-weight: 500; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 12px;">Mock Simulator (Development Mode)</div>
          <div class="button-stack" style="margin-top: 0;">
            <button class="btn btn-secondary" style="flex: 1;" onclick="submitGoogleLogin('mock-google-new')">New User (Needs Phone)</button>
            <button class="btn btn-secondary" style="flex: 1;" onclick="submitGoogleLogin('mock-google-returning')">Returning User</button>
          </div>
        </div>

        <!-- 5. SESSION / ME -->
        <div class="tab-content" id="tab-session">
          <div class="form-item">
            <label>Bearer Token (Sanctum)</label>
            <input type="text" id="active_token" placeholder="Token otomatis terisi setelah login" style="font-family: 'Geist Mono', monospace; font-size: 11px;">
          </div>
          <div class="button-stack">
            <button class="btn btn-primary" style="flex: 1;" onclick="fetchMe()">GET /auth/me</button>
            <button class="btn btn-destructive" onclick="submitLogout()">POST /logout</button>
          </div>
        </div>
      </div>

      <!-- RIGHT: LIVE API INSPECTOR -->
      <div class="card">
        <div class="inspector-top">
          <div style="font-size: 13px; font-weight: 600; color: var(--foreground);">API Inspector</div>
          <div id="statusBadge" class="badge">READY</div>
        </div>

        <div class="endpoint-display">
          <span class="method-tag" id="reqMethod">IDLE</span>
          <span id="reqUrl" style="color: var(--muted-foreground);">Menunggu panggilan API...</span>
          <span id="reqLatency" style="margin-left: auto; color: var(--muted); font-size: 11px;"></span>
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
          <label style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--muted); font-weight: 500;">Response Envelope</label>
          <button class="btn btn-secondary" style="height: 26px; padding: 0 8px; font-size: 11px;" onclick="copyResponseJson()">Copy JSON</button>
        </div>

        <pre class="json-codeblock" id="jsonOutput">// Lakukan aksi di panel kiri untuk melihat respons JSON terformat di sini...</pre>
      </div>
    </div>
  </div>

  <!-- TOAST CONTAINER -->
  <div class="toast-container" id="toastContainer"></div>

  @include('partials.playground-scripts')
</body>
</html>
