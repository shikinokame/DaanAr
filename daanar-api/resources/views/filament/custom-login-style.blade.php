<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,600;0,700;1,400&family=JetBrains+Mono:wght@400;500&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">

<style>
    :root {
        --daan-obsidian: #0C0B09;
        --daan-surface:  #14120F;
        --daan-elevated: #1B1814;
        --daan-border:   rgba(243, 239, 230, 0.10);
        --daan-brass:    #D4A056;
        --daan-brass-hi: #E2B26B;
        --daan-text:     #F3EFE6;
        --daan-muted:    #9E9587;
    }

    /* ── Global Admin Canvas ─────────────────────────────────────── */
    body.fi-body {
        background-color: var(--daan-obsidian) !important;
        background-image: radial-gradient(rgba(212, 160, 86, 0.05) 1px, transparent 1px) !important;
        background-size: 32px 32px !important;
        color: var(--daan-text) !important;
        font-family: 'Plus Jakarta Sans', sans-serif !important;
        -webkit-font-smoothing: antialiased;
    }

    /* ── Topbar & Sidebar ────────────────────────────────────────── */
    .fi-topbar > nav {
        background-color: rgba(12, 11, 9, 0.90) !important;
        backdrop-filter: blur(12px) !important;
        border-bottom: 1px solid var(--daan-border) !important;
    }

    .fi-sidebar {
        background-color: var(--daan-surface) !important;
        border-right: 1px solid var(--daan-border) !important;
    }

    .fi-sidebar-header {
        background-color: transparent !important;
        border-bottom: 1px solid var(--daan-border) !important;
    }

    /* Brand Logo in Sidebar & Login */
    .fi-logo {
        font-family: 'Cormorant Garamond', Georgia, serif !important;
        font-size: 1.65rem !important;
        font-weight: 700 !important;
        color: var(--daan-brass) !important;
        letter-spacing: -0.01em !important;
    }

    /* Sidebar Navigation Items */
    .fi-sidebar-group-label {
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 0.68rem !important;
        text-transform: uppercase !important;
        letter-spacing: 0.14em !important;
        color: var(--daan-muted) !important;
    }

    .fi-sidebar-item-active > a {
        background-color: rgba(212, 160, 86, 0.10) !important;
        border: 1px solid rgba(212, 160, 86, 0.35) !important;
        border-radius: 6px !important;
    }

    .fi-sidebar-item-active .fi-sidebar-item-label,
    .fi-sidebar-item-active .fi-sidebar-item-icon {
        color: var(--daan-brass) !important;
    }

    /* ── Page Headers & Editorial Serif Headings ─────────────────── */
    .fi-header-heading {
        font-family: 'Cormorant Garamond', Georgia, serif !important;
        font-size: 2.35rem !important;
        font-weight: 600 !important;
        letter-spacing: -0.01em !important;
        color: var(--daan-text) !important;
    }

    .fi-breadcrumbs-item-label {
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 0.72rem !important;
        text-transform: uppercase !important;
        letter-spacing: 0.08em !important;
    }

    /* ── Sections, Widgets, Cards, Tables, Modals & Dropdowns ────── */
    .fi-section,
    .fi-ta-ctn,
    .fi-wi-stats-overview-stat,
    .fi-wi-account > div,
    .fi-modal-window,
    .fi-dropdown-panel,
    .fi-no-notification {
        background-color: var(--daan-surface) !important;
        border: 1px solid var(--daan-border) !important;
        border-radius: 8px !important;
        box-shadow: 0 12px 32px rgba(0, 0, 0, 0.35) !important;
    }

    .fi-dropdown-list-item:hover,
    .fi-dropdown-list-item:focus {
        background-color: rgba(212, 160, 86, 0.08) !important;
    }

    .fi-modal-header,
    .fi-modal-footer {
        background-color: var(--daan-surface) !important;
        border-color: var(--daan-border) !important;
    }

    .fi-section-header-heading,
    .fi-ta-header-heading,
    .fi-modal-heading {
        font-family: 'Cormorant Garamond', Georgia, serif !important;
        font-size: 1.4rem !important;
        font-weight: 600 !important;
        color: var(--daan-text) !important;
    }

    .fi-wi-stats-overview-stat-value {
        font-family: 'Cormorant Garamond', Georgia, serif !important;
        font-size: 2.4rem !important;
        font-weight: 700 !important;
        color: var(--daan-text) !important;
    }

    .fi-wi-stats-overview-stat-label {
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 0.72rem !important;
        text-transform: uppercase !important;
        letter-spacing: 0.1em !important;
        color: var(--daan-muted) !important;
    }

    /* Table Header & Rows */
    .fi-ta-header-cell {
        background-color: var(--daan-elevated) !important;
        font-family: 'JetBrains Mono', monospace !important;
        font-size: 0.7rem !important;
        text-transform: uppercase !important;
        letter-spacing: 0.09em !important;
        color: var(--daan-muted) !important;
    }

    .fi-ta-row:hover {
        background-color: rgba(212, 160, 86, 0.04) !important;
    }

    /* Form Inputs & Selects */
    .fi-input-wrp {
        background-color: var(--daan-obsidian) !important;
        border-color: var(--daan-border) !important;
        border-radius: 6px !important;
    }

    .fi-input-wrp:focus-within {
        border-color: var(--daan-brass) !important;
        box-shadow: 0 0 0 1px var(--daan-brass) !important;
    }

    /* Primary Buttons */
    .fi-btn-color-primary {
        background-color: var(--daan-brass) !important;
        color: var(--daan-obsidian) !important;
        border-radius: 5px !important;
        font-weight: 600 !important;
    }
    .fi-btn-color-primary:hover {
        background-color: var(--daan-brass-hi) !important;
    }

    /* ── Login Screen (Preserves Watermark + Adds HUD Aesthetic) ── */
    .fi-simple-layout {
        position: relative !important;
        background-color: var(--daan-obsidian) !important;
        overflow: hidden !important;
        min-height: 100vh !important;
    }

    .fi-simple-layout::before {
        content: '';
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        width: min(85vw, 720px);
        height: min(85vw, 720px);
        background-image: url('{{ asset('logo.png') }}');
        background-repeat: no-repeat;
        background-position: center;
        background-size: contain;
        opacity: 0.14;
        pointer-events: none;
        z-index: 0;
        border-radius: 50%;
        filter: sepia(0.25) contrast(1.1) drop-shadow(0 0 50px rgba(0, 0, 0, 0.9));
    }

    .fi-simple-layout::after {
        content: '';
        position: fixed;
        inset: 0;
        background: radial-gradient(circle at center, rgba(12, 11, 9, 0.25) 0%, rgba(12, 11, 9, 0.9) 100%);
        pointer-events: none;
        z-index: 1;
    }

    .fi-simple-main-ctn {
        position: relative !important;
        z-index: 10 !important;
    }

    .fi-simple-main {
        position: relative !important;
        z-index: 10 !important;
        max-width: 430px !important;
        width: 100% !important;
        background: rgba(20, 18, 15, 0.92) !important;
        backdrop-filter: blur(16px) !important;
        -webkit-backdrop-filter: blur(16px) !important;
        border: 1px solid var(--daan-border) !important;
        box-shadow: 0 28px 64px rgba(0, 0, 0, 0.8) !important;
        border-radius: 8px !important;
        padding: 2.5rem !important;
    }

    /* HUD Corner Reticles on Login Box */
    .fi-simple-main::before,
    .fi-simple-main::after {
        content: '';
        position: absolute;
        width: 14px;
        height: 14px;
        pointer-events: none;
    }
    .fi-simple-main::before {
        top: -1px; left: -1px;
        border-top: 2px solid var(--daan-brass);
        border-left: 2px solid var(--daan-brass);
    }
    .fi-simple-main::after {
        bottom: -1px; right: -1px;
        border-bottom: 2px solid var(--daan-brass);
        border-right: 2px solid var(--daan-brass);
    }

    .fi-simple-header-heading {
        font-family: 'Cormorant Garamond', Georgia, serif !important;
        color: var(--daan-text) !important;
        font-size: 1.85rem !important;
        font-weight: 600 !important;
    }
</style>
