<style>
  /*
   * shadcn/ui Design System Tokens (Dark Zinc Theme)
   * High-contrast, minimal, developer-grade interface
   */
  :root {
    --background: #09090b;
    --foreground: #fafafa;
    
    --card: #09090b;
    --card-foreground: #fafafa;
    
    --popover: #09090b;
    --popover-foreground: #fafafa;
    
    --primary: #fafafa;
    --primary-foreground: #18181b;
    --primary-hover: #e4e4e7;
    
    --secondary: #18181b;
    --secondary-foreground: #fafafa;
    --secondary-hover: #27272a;
    
    --muted: #18181b;
    --muted-foreground: #a1a1aa;
    
    --accent: #27272a;
    --accent-foreground: #fafafa;
    
    --destructive: #ef4444;
    --destructive-foreground: #fafafa;
    --destructive-hover: #dc2626;

    --border: #27272a;
    --input: #27272a;
    --ring: #71717a;

    --radius: 6px;
    --font-sans: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    --font-mono: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  }

  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }

  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: var(--font-sans);
    font-size: 13px;
    line-height: 1.5;
    min-height: 100vh;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    letter-spacing: -0.01em;
  }

  /* TOP NAVBAR */
  .navbar {
    position: sticky;
    top: 0;
    z-index: 50;
    width: 100%;
    border-bottom: 1px solid var(--border);
    background-color: rgba(9, 9, 11, 0.85);
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
  }

  .navbar-container {
    max-width: 1440px;
    margin: 0 auto;
    padding: 0 24px;
    height: 56px;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .nav-brand {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .nav-logo-icon {
    width: 28px;
    height: 28px;
    border-radius: var(--radius);
    background: #fafafa;
    color: #09090b;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 13px;
    font-family: var(--font-mono);
  }

  .nav-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--foreground);
    display: flex;
    align-items: center;
    gap: 8px;
    letter-spacing: -0.02em;
  }

  .nav-badge {
    display: inline-flex;
    align-items: center;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background: var(--muted);
    padding: 2px 8px;
    font-size: 11px;
    font-weight: 500;
    font-family: var(--font-mono);
    color: var(--muted-foreground);
  }

  .nav-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .session-status-badge {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 4px 10px;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background: var(--muted);
    font-size: 12px;
    font-family: var(--font-mono);
    color: var(--muted-foreground);
    transition: all 0.2s ease;
  }

  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #71717a;
    transition: all 0.3s ease;
  }

  .status-dot.active {
    background: #22c55e;
    box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.7);
    animation: statusPulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }

  @keyframes statusPulse {
    0% {
      box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.5);
    }
    70% {
      box-shadow: 0 0 0 6px rgba(34, 197, 94, 0);
    }
    100% {
      box-shadow: 0 0 0 0 rgba(34, 197, 94, 0);
    }
  }

  #sessionStatus {
    transition: opacity 0.15s ease;
  }

  /* SUBHEADER / STATUS BAR */
  .subheader-bar {
    border-bottom: 1px solid var(--border);
    background: #09090b;
    padding: 8px 24px;
  }

  .subheader-container {
    max-width: 1440px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 12px;
    color: var(--muted-foreground);
  }

  .meta-chips {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .meta-chip {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .meta-chip svg {
    width: 13px;
    height: 13px;
    opacity: 0.7;
  }

  /* MAIN CONTAINER */
  .main-shell {
    max-width: 1440px;
    margin: 0 auto;
    padding: 24px;
  }

  /* WORKSPACE GRID */
  .workspace-grid {
    display: grid;
    grid-template-columns: 1fr 1.1fr;
    gap: 24px;
    align-items: start;
  }

  @media (max-width: 1080px) {
    .workspace-grid {
      grid-template-columns: 1fr;
    }
  }

  /* SHADCN CARD */
  .card {
    border-radius: calc(var(--radius) + 2px);
    border: 1px solid var(--border);
    background-color: var(--card);
    color: var(--card-foreground);
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.2);
  }

  .card-header {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 20px 20px 16px;
    border-bottom: 1px solid var(--border);
  }

  .card-title {
    font-size: 15px;
    font-weight: 600;
    letter-spacing: -0.02em;
    color: var(--foreground);
  }

  .card-description {
    font-size: 12.5px;
    color: var(--muted-foreground);
    line-height: 1.4;
  }

  .card-content {
    padding: 20px;
  }

  /* SHADCN TABS LIST */
  .nav-groups {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-bottom: 20px;
  }

  .tabs-list {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 3px;
    border-radius: var(--radius);
    background: var(--muted);
    border: 1px solid var(--border);
    overflow-x: auto;
  }

  .tabs-group-label {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--muted-foreground);
    padding: 0 8px;
    white-space: nowrap;
  }

  .tab-trigger {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
    border-radius: 4px;
    padding: 5px 11px;
    font-size: 12px;
    font-weight: 500;
    color: var(--muted-foreground);
    background: transparent;
    border: none;
    cursor: pointer;
    transition: all 0.18s cubic-bezier(0.16, 1, 0.3, 1);
    font-family: inherit;
  }

  .tab-trigger:hover {
    color: var(--foreground);
  }

  .tab-trigger:active {
    transform: scale(0.97);
  }

  .tab-trigger.active {
    background-color: var(--background);
    color: var(--foreground);
    font-weight: 600;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.08);
  }

  /* TAB CONTENT */
  .tab-content {
    display: none;
  }

  .tab-content.active {
    display: block;
    animation: tabEnter 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }

  @keyframes tabEnter {
    from { opacity: 0; transform: translateY(6px); }
    to { opacity: 1; transform: translateY(0); }
  }

  /* FORM ITEMS */
  .form-item {
    display: flex;
    flex-direction: column;
    gap: 6px;
    margin-bottom: 14px;
  }

  .form-label {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    font-weight: 500;
    color: var(--foreground);
  }

  .form-hint {
    font-size: 11px;
    font-weight: 400;
    color: var(--muted-foreground);
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }

  /* SHADCN INPUT */
  input[type="text"],
  input[type="email"],
  input[type="password"],
  input[type="number"],
  select {
    display: flex;
    height: 36px;
    width: 100%;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background-color: transparent;
    padding: 0 12px;
    font-size: 13px;
    font-family: inherit;
    color: var(--foreground);
    outline: none;
    transition: border-color 0.15s, box-shadow 0.15s;
  }

  input::placeholder {
    color: #52525b;
  }

  input:focus,
  select:focus {
    border-color: var(--ring);
    box-shadow: 0 0 0 1px var(--ring);
  }

  input[type="file"] {
    display: flex;
    width: 100%;
    border-radius: var(--radius);
    border: 1px dashed var(--border);
    background-color: var(--muted);
    padding: 6px;
    font-size: 12px;
    color: var(--muted-foreground);
    cursor: pointer;
    transition: border-color 0.15s;
  }

  input[type="file"]:hover {
    border-color: #52525b;
  }

  input[type="file"]::file-selector-button {
    background: var(--secondary);
    border: 1px solid var(--border);
    border-radius: 4px;
    color: var(--foreground);
    padding: 3px 8px;
    margin-right: 8px;
    cursor: pointer;
    font-size: 11px;
    font-weight: 500;
  }

  /* SHADCN BUTTONS */
  .button-stack {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 18px;
  }

  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
    border-radius: var(--radius);
    font-size: 12.5px;
    font-weight: 500;
    height: 36px;
    padding: 0 14px;
    cursor: pointer;
    transition: all 0.18s cubic-bezier(0.16, 1, 0.3, 1);
    border: 1px solid transparent;
    font-family: inherit;
    text-decoration: none;
    user-select: none;
  }

  .btn:active {
    transform: scale(0.97);
  }

  .btn:disabled, .btn.is-loading {
    pointer-events: none;
    opacity: 0.65;
    cursor: not-allowed;
  }

  .btn-spinner {
    display: inline-block;
    width: 12px;
    height: 12px;
    border: 2px solid currentColor;
    border-right-color: transparent;
    border-radius: 50%;
    animation: btnSpin 0.6s linear infinite;
    margin-right: 6px;
  }

  @keyframes btnSpin {
    to { transform: rotate(360deg); }
  }

  /* Primary: Stark Solid White on Dark */
  .btn-primary {
    background-color: var(--primary);
    color: var(--primary-foreground);
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .btn-primary:hover {
    background-color: var(--primary-hover);
  }

  /* Secondary: Subtle outline */
  .btn-secondary {
    background-color: transparent;
    border: 1px solid var(--border);
    color: var(--foreground);
  }

  .btn-secondary:hover {
    background-color: var(--secondary);
    border-color: #3f3f46;
  }

  /* Emerald Action: Clean Accent */
  .btn-emerald {
    background-color: #15803d;
    color: #fafafa;
    border: 1px solid #166534;
  }

  .btn-emerald:hover {
    background-color: #166534;
  }

  /* Destructive */
  .btn-destructive {
    background-color: #27272a;
    border: 1px solid #3f3f46;
    color: #f87171;
  }

  .btn-destructive:hover {
    background-color: #7f1d1d;
    color: #fafafa;
    border-color: #991b1b;
  }

  .btn-sm {
    height: 30px;
    padding: 0 10px;
    font-size: 11.5px;
  }

  /* SEPARATOR / DIVIDER */
  .separator {
    height: 1px;
    width: 100%;
    background-color: var(--border);
    margin: 18px 0;
  }

  .section-title {
    font-size: 12px;
    font-weight: 600;
    color: var(--foreground);
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  /* CATEGORY CHECKBOX LIST */
  .category-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 6px;
  }

  .category-chip {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 10px;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background: transparent;
    cursor: pointer;
    transition: all 0.15s;
    user-select: none;
  }

  .category-chip:hover {
    background: var(--secondary);
    border-color: #3f3f46;
  }

  .category-chip input[type="checkbox"] {
    accent-color: #fafafa;
    width: 14px;
    height: 14px;
    cursor: pointer;
  }

  .category-chip-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--foreground);
  }

  /* RIGHT INSPECTOR PANEL */
  .inspector-card {
    border-radius: calc(var(--radius) + 2px);
    border: 1px solid var(--border);
    background-color: var(--card);
    display: flex;
    flex-direction: column;
  }

  .inspector-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-bottom: 1px solid var(--border);
  }

  .endpoint-strip {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 14px;
    border-radius: var(--radius);
    background: #000000;
    border: 1px solid var(--border);
    margin: 16px 20px 12px;
    font-family: var(--font-mono);
    font-size: 12px;
  }

  /* METHOD BADGES (Shadcn Subtle Tones) */
  .method-badge {
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 10.5px;
    font-weight: 600;
    text-transform: uppercase;
    font-family: var(--font-mono);
    border: 1px solid transparent;
  }

  .method-GET {
    background: rgba(56, 189, 248, 0.1);
    color: #38bdf8;
    border-color: rgba(56, 189, 248, 0.2);
  }

  .method-POST {
    background: rgba(34, 197, 94, 0.1);
    color: #22c55e;
    border-color: rgba(34, 197, 94, 0.2);
  }

  .method-PUT {
    background: rgba(234, 179, 8, 0.1);
    color: #eab308;
    border-color: rgba(234, 179, 8, 0.2);
  }

  .method-DELETE {
    background: rgba(239, 68, 68, 0.1);
    color: #ef4444;
    border-color: rgba(239, 68, 68, 0.2);
  }

  /* STATUS BADGES & ALIASES */
  .status-badge, .badge {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 2px 8px;
    border-radius: var(--radius);
    border: 1px solid var(--border);
    background: var(--muted);
    font-size: 11px;
    font-weight: 500;
    font-family: var(--font-mono);
    color: var(--muted-foreground);
  }

  .status-2xx, .badge-success {
    border-color: rgba(34, 197, 94, 0.3);
    background: rgba(34, 197, 94, 0.1);
    color: #4ade80;
  }

  .status-4xx, .badge-destructive {
    border-color: rgba(239, 68, 68, 0.3);
    background: rgba(239, 68, 68, 0.1);
    color: #f87171;
  }

  .status-5xx {
    border-color: rgba(239, 68, 68, 0.4);
    background: rgba(239, 68, 68, 0.15);
    color: #fca5a5;
  }

  /* JSON CODE VIEWPORT */
  .viewport-container {
    padding: 0 20px 20px;
    display: flex;
    flex-direction: column;
    flex: 1;
  }

  .viewport-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }

  .viewport-label {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--muted-foreground);
  }

  .json-viewport {
    background-color: #000000;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 14px 16px;
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.6;
    color: #d4d4d8;
    min-height: 440px;
    max-height: 560px;
    overflow-y: auto;
    white-space: pre-wrap;
    word-break: break-word;
    transition: opacity 0.2s cubic-bezier(0.16, 1, 0.3, 1), border-color 0.2s ease;
  }

  .json-viewport.is-loading {
    opacity: 0.35;
  }

  /* CUSTOM MINIMAL SCROLLBAR */
  ::-webkit-scrollbar {
    width: 6px;
    height: 6px;
  }
  ::-webkit-scrollbar-track {
    background: transparent;
  }
  ::-webkit-scrollbar-thumb {
    background: #27272a;
    border-radius: 3px;
  }
  ::-webkit-scrollbar-thumb:hover {
    background: #3f3f46;
  }

  /* TOAST (Shadcn Sonner Style) */
  .toast-container {
    position: fixed;
    bottom: 24px;
    right: 24px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    z-index: 100;
    pointer-events: none;
  }

  .toast {
    pointer-events: auto;
    display: flex;
    flex-direction: column;
    gap: 3px;
    background-color: #09090b;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 12px 14px;
    min-width: 280px;
    max-width: 360px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
    animation: toastEnter 0.24s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    transition: all 0.24s cubic-bezier(0.16, 1, 0.3, 1);
  }

  @keyframes toastEnter {
    from {
      opacity: 0;
      transform: translateY(12px) scale(0.96);
    }
    to {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
  }

  .toast.toast-exit {
    opacity: 0;
    transform: translateX(18px) scale(0.95);
  }

  .toast-title {
    font-size: 12.5px;
    font-weight: 600;
    color: var(--foreground);
  }

  .toast-desc {
    font-size: 12px;
    color: var(--muted-foreground);
    line-height: 1.4;
  }

  .toast-code {
    font-family: var(--font-mono);
    font-size: 11px;
    background: #18181b;
    border: 1px solid var(--border);
    padding: 3px 6px;
    border-radius: 4px;
    color: #38bdf8;
    margin-top: 4px;
  }
</style>
