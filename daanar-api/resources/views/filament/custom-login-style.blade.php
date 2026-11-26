<style>
    .fi-panel-admin {
        background-color: #f6f4ef;
        --login-watermark-opacity: 0.09;
        --login-watermark-shadow: none;
        --login-vignette: radial-gradient(circle at center, transparent, #e9e1d4aa);
        --login-card: #fffdfa;
        --login-border: #ded7c9;
        --login-shadow: 0 20px 50px -20px rgb(56 45 28 / 25%);
        --login-heading: #242b23;
        --login-input: #fff;
        --login-input-border: #bcb7ac;
        --login-input-text: #242b23;
        --login-focus: #a64f08;
        --login-button: #a64f08;
        --login-button-hover: #8c4008;
    }

    html.dark .fi-panel-admin {
        background-color: #0b0f19;
        --login-watermark-opacity: 0.18;
        --login-watermark-shadow: drop-shadow(0 0 50px rgb(0 0 0 / 90%));
        --login-vignette: radial-gradient(circle at center, rgb(11 15 25 / 30%), rgb(7 10 18 / 85%));
        --login-card: rgb(18 24 38 / 92%);
        --login-border: rgb(255 255 255 / 9%);
        --login-shadow: 0 25px 60px -15px rgb(0 0 0 / 75%), 0 0 35px rgb(245 158 11 / 8%);
        --login-heading: #f3f4f6;
        --login-input: rgb(13 18 30 / 80%);
        --login-input-border: rgb(255 255 255 / 12%);
        --login-input-text: #f9fafb;
        --login-focus: #f59e0b;
        --login-button: linear-gradient(135deg, #f59e0b, #d97706);
        --login-button-hover: linear-gradient(135deg, #fbbf24, #f59e0b);
    }

    html:not(.dark) .fi-panel-admin .fi-main-sidebar {
        background-color: #fcfaf5;
        border-inline-end: 1px solid #e7e0d3;
    }

    html:not(.dark) .fi-panel-admin :is(.fi-topbar > nav, .fi-sidebar-header) {
        background-color: #fffdfa;
    }

    html:not(.dark) .fi-panel-admin .fi-sidebar-item.fi-active > .fi-sidebar-item-button {
        background-color: #f5ead3;
    }

    html:not(.dark) .fi-panel-admin .fi-sidebar-item.fi-active :is(.fi-sidebar-item-icon, .fi-sidebar-item-label) {
        color: #81500f;
    }

    .fi-simple-layout {
        position: relative !important;
        overflow: hidden !important;
        min-height: 100vh !important;
    }

    /* Giant watermark logo in the background */
    .fi-simple-layout::before {
        content: '';
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        width: min(85vw, 760px);
        height: min(85vw, 760px);
        background-image: url('{{ asset('logo.png') }}');
        background-repeat: no-repeat;
        background-position: center;
        background-size: contain;
        opacity: var(--login-watermark-opacity);
        pointer-events: none;
        z-index: 0;
        border-radius: 50%;
        filter: var(--login-watermark-shadow);
    }

    /* Subtle ambient gradient over the background */
    .fi-simple-layout::after {
        content: '';
        position: fixed;
        inset: 0;
        background: var(--login-vignette);
        pointer-events: none;
        z-index: 1;
    }

    .fi-simple-main-ctn {
        position: relative !important;
        z-index: 10 !important;
    }

    /* Login Card Styling */
    .fi-simple-main {
        position: relative !important;
        z-index: 10 !important;
        max-width: 440px !important;
        width: 100% !important;
        background: var(--login-card) !important;
        backdrop-filter: blur(18px) !important;
        -webkit-backdrop-filter: blur(18px) !important;
        border: 1px solid var(--login-border) !important;
        box-shadow: var(--login-shadow) !important;
        border-radius: 1.25rem !important;
        padding: 2.25rem !important;
    }

    /* Brand Logo / Header */
    .fi-simple-header .fi-logo {
        color: var(--login-heading) !important;
        font-weight: 700 !important;
        letter-spacing: 0.05em !important;
    }

    .fi-simple-header-heading {
        color: var(--login-heading) !important;
        font-size: 1.5rem !important;
        font-weight: 700 !important;
    }

    /* Inputs */
    .fi-simple-main input[type="email"],
    .fi-simple-main input[type="password"],
    .fi-simple-main input[type="text"] {
        background-color: var(--login-input) !important;
        border: 1px solid var(--login-input-border) !important;
        border-radius: 0.625rem !important;
        color: var(--login-input-text) !important;
        padding: 0.75rem 1rem !important;
    }

    .fi-simple-main input[type="email"]:focus,
    .fi-simple-main input[type="password"]:focus,
    .fi-simple-main input[type="text"]:focus {
        border-color: var(--login-focus) !important;
        box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.25) !important;
    }

    /* Submit Button (Sign in) */
    .fi-simple-main button[type="submit"],
    .fi-simple-main .fi-btn-primary {
        background: var(--login-button) !important;
        color: #ffffff !important;
        font-weight: 600 !important;
        font-size: 0.95rem !important;
        border-radius: 0.625rem !important;
        padding: 0.75rem 1.5rem !important;
        box-shadow: 0 4px 14px rgba(245, 158, 11, 0.35) !important;
        border: none !important;
        transition: all 0.2s ease-in-out !important;
        width: 100% !important;
        display: flex !important;
        justify-content: center !important;
        align-items: center !important;
    }

    .fi-simple-main button[type="submit"]:hover,
    .fi-simple-main .fi-btn-primary:hover {
        background: var(--login-button-hover) !important;
        transform: translateY(-1px) !important;
        box-shadow: 0 6px 20px rgba(245, 158, 11, 0.45) !important;
    }

    .fi-simple-main button[type="submit"]:active,
    .fi-simple-main .fi-btn-primary:active {
        transform: translateY(0) !important;
    }
</style>
