<style>
    /* Dark aesthetic with centered DaanAR watermark logo */
    body.fi-body {
        background-color: #0b0f19 !important;
    }

    .fi-simple-layout {
        position: relative !important;
        background-color: #0b0f19 !important;
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
        opacity: 0.18;
        pointer-events: none;
        z-index: 0;
        border-radius: 50%;
        filter: drop-shadow(0 0 50px rgba(0, 0, 0, 0.9));
    }

    /* Subtle ambient dark gradient over the background */
    .fi-simple-layout::after {
        content: '';
        position: fixed;
        inset: 0;
        background: radial-gradient(circle at center, rgba(11, 15, 25, 0.3) 0%, rgba(7, 10, 18, 0.85) 100%);
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
        background: rgba(18, 24, 38, 0.88) !important;
        backdrop-filter: blur(18px) !important;
        -webkit-backdrop-filter: blur(18px) !important;
        border: 1px solid rgba(255, 255, 255, 0.09) !important;
        box-shadow: 0 25px 60px -15px rgba(0, 0, 0, 0.75), 0 0 35px rgba(245, 158, 11, 0.08) !important;
        border-radius: 1.25rem !important;
        padding: 2.5rem !important;
    }

    /* Brand Logo / Header */
    .fi-simple-header .fi-logo {
        color: #ffffff !important;
        font-weight: 700 !important;
        letter-spacing: 0.05em !important;
    }

    .fi-simple-header-heading {
        color: #f3f4f6 !important;
        font-size: 1.5rem !important;
        font-weight: 700 !important;
    }

    /* Inputs */
    .fi-simple-main input[type="email"],
    .fi-simple-main input[type="password"],
    .fi-simple-main input[type="text"] {
        background-color: rgba(13, 18, 30, 0.8) !important;
        border: 1px solid rgba(255, 255, 255, 0.12) !important;
        border-radius: 0.625rem !important;
        color: #f9fafb !important;
        padding: 0.75rem 1rem !important;
    }

    .fi-simple-main input[type="email"]:focus,
    .fi-simple-main input[type="password"]:focus,
    .fi-simple-main input[type="text"]:focus {
        border-color: #f59e0b !important;
        box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.25) !important;
    }

    /* Submit Button (Sign in) */
    .fi-simple-main button[type="submit"],
    .fi-simple-main .fi-btn-primary {
        background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%) !important;
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
        background: linear-gradient(135deg, #fbbf24 0%, #f59e0b 100%) !important;
        transform: translateY(-1px) !important;
        box-shadow: 0 6px 20px rgba(245, 158, 11, 0.45) !important;
    }

    .fi-simple-main button[type="submit"]:active,
    .fi-simple-main .fi-btn-primary:active {
        transform: translateY(0) !important;
    }
</style>
