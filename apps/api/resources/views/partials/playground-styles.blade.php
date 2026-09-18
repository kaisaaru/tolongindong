<style>
  :root {
    --background: #09090b;
    --foreground: #fafafa;
    --muted: #71717a;
    --muted-foreground: #a1a1aa;
    --popover: #09090b;
    --popover-foreground: #fafafa;
    --card: #0c0c0e;
    --card-foreground: #fafafa;
    --border: #27272a;
    --input: #27272a;
    --primary: #fafafa;
    --primary-foreground: #18181b;
    --secondary: #27272a;
    --secondary-foreground: #fafafa;
    --accent: #27272a;
    --accent-foreground: #fafafa;
    --destructive: #7f1d1d;
    --destructive-foreground: #fca5a5;
    --ring: #d4d4d8;
    --radius: 8px;
  }

  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: 'Geist', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    font-size: 14px;
    line-height: 1.5;
    min-height: 100vh;
    -webkit-font-smoothing: antialiased;
  }

  .app-shell {
    max-width: 1360px;
    margin: 0 auto;
    padding: 32px 24px 60px;
  }

  /* Header Navbar */
  header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-bottom: 24px;
    border-bottom: 1px solid var(--border);
    margin-bottom: 32px;
  }

  .brand {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .brand-title {
    font-size: 15px;
    font-weight: 600;
    letter-spacing: -0.01em;
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .badge {
    display: inline-flex;
    align-items: center;
    padding: 2px 8px;
    font-size: 11px;
    font-family: 'Geist Mono', monospace;
    font-weight: 500;
    border-radius: 9999px;
    border: 1px solid var(--border);
    color: var(--muted-foreground);
    background: #18181b;
  }

  .badge-success {
    border-color: #064e3b;
    background: #022c22;
    color: #34d399;
  }

  .badge-destructive {
    border-color: #7f1d1d;
    background: #450a0a;
    color: #f87171;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .session-pill {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background: #121215;
    font-size: 12px;
    font-family: 'Geist Mono', monospace;
    color: var(--muted-foreground);
  }

  .status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--muted);
  }

  .status-dot.active {
    background: #10b981;
    box-shadow: 0 0 8px rgba(16, 185, 129, 0.4);
  }

  /* Layout Grid */
  .workspace-grid {
    display: grid;
    grid-template-columns: 1fr 1.15fr;
    gap: 28px;
    align-items: start;
  }

  @media (max-width: 1024px) {
    .workspace-grid {
      grid-template-columns: 1fr;
    }
  }

  /* Shadcn Card */
  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 24px;
  }

  .card-header {
    margin-bottom: 20px;
  }

  .card-title {
    font-size: 14px;
    font-weight: 600;
    letter-spacing: -0.01em;
    color: var(--foreground);
  }

  .card-description {
    font-size: 13px;
    color: var(--muted-foreground);
    margin-top: 4px;
  }

  /* Shadcn Tabs */
  .tabs-list {
    display: inline-flex;
    height: 36px;
    align-items: center;
    justify-content: flex-start;
    border-radius: var(--radius);
    background: #141417;
    padding: 3px;
    border: 1px solid var(--border);
    margin-bottom: 24px;
    width: 100%;
    overflow-x: auto;
  }

  .tab-trigger {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
    border-radius: 6px;
    padding: 4px 12px;
    font-size: 12.5px;
    font-weight: 500;
    color: var(--muted-foreground);
    border: none;
    background: transparent;
    cursor: pointer;
    transition: all 0.15s ease;
    font-family: inherit;
  }

  .tab-trigger:hover {
    color: var(--foreground);
  }

  .tab-trigger.active {
    background: var(--background);
    color: var(--foreground);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
  }

  .tab-content {
    display: none;
  }

  .tab-content.active {
    display: block;
  }

  /* Forms */
  .form-item {
    margin-bottom: 16px;
  }

  .form-item label {
    display: block;
    font-size: 12px;
    font-weight: 500;
    color: var(--foreground);
    margin-bottom: 6px;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  input[type="text"],
  input[type="email"],
  input[type="password"] {
    width: 100%;
    height: 38px;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background: #121215;
    padding: 8px 12px;
    font-size: 13.5px;
    font-family: inherit;
    color: var(--foreground);
    outline: none;
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }

  input:focus {
    border-color: #52525b;
    box-shadow: 0 0 0 1px #52525b;
  }

  .form-description {
    font-size: 12px;
    color: var(--muted);
    margin-top: 6px;
  }

  /* Shadcn Buttons */
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 500;
    height: 38px;
    padding: 0 16px;
    cursor: pointer;
    transition: all 0.15s ease;
    border: none;
    font-family: inherit;
  }

  .btn-primary {
    background: var(--primary);
    color: var(--primary-foreground);
  }

  .btn-primary:hover {
    background: #e4e4e7;
  }

  .btn-secondary {
    background: #18181b;
    border: 1px solid var(--border);
    color: var(--foreground);
  }

  .btn-secondary:hover {
    background: #27272a;
  }

  .btn-destructive {
    background: #450a0a;
    border: 1px solid #7f1d1d;
    color: #fca5a5;
  }

  .btn-destructive:hover {
    background: #7f1d1d;
    color: #fff;
  }

  .btn-full {
    width: 100%;
  }

  .button-stack {
    display: flex;
    gap: 8px;
    margin-top: 20px;
  }

  /* Live Inspector Console */
  .inspector-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid var(--border);
    padding-bottom: 14px;
    margin-bottom: 16px;
  }

  .endpoint-display {
    display: flex;
    align-items: center;
    gap: 10px;
    font-family: 'Geist Mono', monospace;
    font-size: 12.5px;
    background: #121215;
    padding: 8px 12px;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    margin-bottom: 16px;
    overflow-x: auto;
  }

  .method-tag {
    font-weight: 600;
    font-size: 11px;
    letter-spacing: 0.05em;
    padding: 2px 6px;
    border-radius: 4px;
    background: #27272a;
    color: #e4e4e7;
  }

  .method-POST { background: #022c22; color: #34d399; border: 1px solid #064e3b; }
  .method-GET { background: #082f49; color: #38bdf8; border: 1px solid #075985; }

  .json-codeblock {
    background: #000000;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 16px;
    font-family: 'Geist Mono', monospace;
    font-size: 12.5px;
    line-height: 1.6;
    max-height: 520px;
    overflow-y: auto;
    color: #e4e4e7;
    white-space: pre-wrap;
  }

  .divider {
    height: 1px;
    background: var(--border);
    margin: 20px 0;
  }

  /* Notification Banner (Shadcn toast style) */
  .toast-container {
    position: fixed;
    bottom: 24px;
    right: 24px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    z-index: 1000;
    max-width: 380px;
  }

  .toast {
    background: #18181b;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 14px 16px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    animation: enter 0.2s ease-out;
  }

  @keyframes enter {
    from { transform: translateY(12px); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }

  .toast-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--foreground);
    margin-bottom: 2px;
  }

  .toast-desc {
    font-size: 12px;
    color: var(--muted-foreground);
  }

  .toast-code {
    display: inline-block;
    margin-top: 6px;
    font-family: 'Geist Mono', monospace;
    font-size: 15px;
    letter-spacing: 2px;
    font-weight: 600;
    color: #38bdf8;
    background: #09090b;
    padding: 4px 8px;
    border-radius: 4px;
    border: 1px solid #27272a;
  }
</style>
