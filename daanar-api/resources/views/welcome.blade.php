<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DaanAR — Pangasinan Heritage Navigation</title>
    <meta name="description" content="Explore the Spanish colonial and cultural landmarks of Pangasinan through real-time Augmented Reality and spatial navigation.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,600;0,700;1,400;1,600&family=JetBrains+Mono:wght@400;500&family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-obsidian:   #0C0B09;
            --bg-surface:    #14120F;
            --bg-elevated:   #1B1814;
            --border-subtle: rgba(243, 239, 230, 0.11);
            --border-brass:  rgba(212, 160, 86, 0.45);
            --parchment:     #F3EFE6;
            --text-muted:    #9E9587;
            --brass:         #D4A056;
            --brass-hover:   #E2B26B;
            --terracotta:    #C86D51;
            --forest:        #1F3A2E;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        html { scroll-behavior: smooth; }

        body {
            background-color: var(--bg-obsidian);
            background-image: radial-gradient(rgba(212, 160, 86, 0.06) 1px, transparent 1px);
            background-size: 32px 32px;
            color: var(--parchment);
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
            line-height: 1.6;
            overflow-x: hidden;
            -webkit-font-smoothing: antialiased;
        }

        /* ── Custom Scrollbar ───────────────────────────── */
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: var(--bg-obsidian); }
        ::-webkit-scrollbar-thumb { background: var(--brass); border-radius: 2px; }

        /* ── Typography Utilities ───────────────────────── */
        .font-serif { font-family: 'Cormorant Garamond', Georgia, serif; }
        .font-mono  { font-family: 'JetBrains Mono', monospace; }

        .container {
            max-width: 1240px;
            margin: 0 auto;
            padding: 0 32px;
        }

        /* ── HUD Corner Reticles ────────────────────────── */
        .hud-frame { position: relative; }
        .hud-frame::before,
        .hud-frame::after {
            content: '';
            position: absolute;
            width: 12px;
            height: 12px;
            pointer-events: none;
            z-index: 10;
        }
        .hud-frame::before {
            top: -1px; left: -1px;
            border-top: 1.5px solid var(--brass);
            border-left: 1.5px solid var(--brass);
        }
        .hud-frame::after {
            bottom: -1px; right: -1px;
            border-bottom: 1.5px solid var(--brass);
            border-right: 1.5px solid var(--brass);
        }

        /* ── Navbar ─────────────────────────────────────── */
        nav {
            position: fixed;
            top: 0; left: 0; right: 0;
            z-index: 100;
            background: rgba(12, 11, 9, 0.88);
            backdrop-filter: blur(14px);
            border-bottom: 1px solid var(--border-subtle);
        }
        .nav-inner {
            max-width: 1240px;
            margin: 0 auto;
            padding: 0 32px;
            height: 76px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .nav-logo {
            display: inline-flex;
            align-items: center;
            gap: 12px;
            text-decoration: none;
            color: var(--parchment);
        }
        .nav-logo-mark {
            width: 34px;
            height: 34px;
            border: 1px solid var(--border-brass);
            background: rgba(212, 160, 86, 0.08);
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: var(--brass);
        }
        .nav-logo-text {
            font-family: 'Cormorant Garamond', serif;
            font-size: 26px;
            font-weight: 700;
            letter-spacing: -0.02em;
        }
        .nav-logo-text span {
            color: var(--brass);
            font-style: italic;
            font-weight: 600;
        }
        .nav-links {
            display: flex;
            gap: 36px;
            list-style: none;
        }
        .nav-links a {
            color: var(--text-muted);
            text-decoration: none;
            font-size: 14px;
            font-weight: 500;
            transition: color 0.2s;
        }
        .nav-links a:hover { color: var(--parchment); }
        .nav-admin {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.12em;
            color: var(--parchment);
            border: 1px solid var(--border-subtle);
            padding: 9px 16px;
            border-radius: 4px;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s;
        }
        .nav-admin:hover {
            border-color: var(--brass);
            color: var(--brass);
            background: rgba(212, 160, 86, 0.06);
        }

        /* ── Hero (Asymmetric Split) ────────────────────── */
        .hero {
            padding: 148px 0 96px;
            border-bottom: 1px solid var(--border-subtle);
            position: relative;
        }
        .hero-grid {
            display: grid;
            grid-template-columns: 1.15fr 0.85fr;
            gap: 56px;
            align-items: center;
        }
        .eyebrow-pill {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            padding: 6px 14px;
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: 999px;
            margin-bottom: 24px;
        }
        .pulse-dot {
            width: 7px;
            height: 7px;
            border-radius: 50%;
            background: var(--brass);
            box-shadow: 0 0 10px var(--brass);
        }
        .eyebrow-text {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.14em;
            color: var(--brass);
        }
        .hero h1 {
            font-family: 'Cormorant Garamond', serif;
            font-size: clamp(44px, 5.5vw, 72px);
            font-weight: 600;
            line-height: 1.04;
            letter-spacing: -0.02em;
            margin-bottom: 24px;
        }
        .hero h1 em {
            color: var(--brass);
            font-style: italic;
            font-weight: 400;
        }
        .hero-lead {
            font-size: 17px;
            color: var(--text-muted);
            max-width: 540px;
            line-height: 1.75;
            margin-bottom: 36px;
        }
        .hero-actions {
            display: flex;
            gap: 14px;
            flex-wrap: wrap;
            margin-bottom: 48px;
        }
        .btn-brass {
            background: var(--brass);
            color: var(--bg-obsidian);
            padding: 14px 26px;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 600;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 10px;
            transition: all 0.2s;
        }
        .btn-brass:hover {
            background: var(--brass-hover);
            transform: translateY(-1px);
        }
        .btn-outline {
            background: transparent;
            color: var(--parchment);
            padding: 14px 24px;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 500;
            text-decoration: none;
            border: 1px solid var(--border-subtle);
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s;
        }
        .btn-outline:hover {
            border-color: var(--brass);
            color: var(--brass);
        }
        .hero-meta-strip {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 24px;
            padding-top: 28px;
            border-top: 1px solid var(--border-subtle);
            max-width: 520px;
        }
        .meta-label {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            color: var(--text-muted);
        }
        .meta-value {
            font-family: 'Cormorant Garamond', serif;
            font-size: 24px;
            font-weight: 600;
            color: var(--parchment);
            margin-top: 2px;
        }

        /* ── Hero AR Viewport Card (Interactive) ────────── */
        .ar-viewport {
            display: block;
            text-decoration: none;
            color: inherit;
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: 10px;
            padding: 12px;
            box-shadow: 0 24px 60px rgba(0, 0, 0, 0.65);
            transition: border-color 0.25s, transform 0.25s;
        }
        .ar-viewport:hover {
            border-color: var(--border-brass);
            transform: translateY(-3px);
        }
        .ar-hud-bar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 14px;
            background: var(--bg-obsidian);
            border: 1px solid var(--border-subtle);
            border-bottom: none;
            border-radius: 6px 6px 0 0;
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            color: var(--text-muted);
        }
        .ar-screen {
            position: relative;
            height: 410px;
            border-radius: 0 0 6px 6px;
            overflow: hidden;
            background: linear-gradient(145deg, #1b221e, #12100e);
            border: 1px solid var(--border-subtle);
        }
        .ar-screen img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            opacity: 0.68;
            filter: contrast(1.08) sepia(0.18);
            transition: transform 0.5s ease, opacity 0.3s ease;
        }
        .ar-viewport:hover .ar-screen img {
            transform: scale(1.04);
            opacity: 0.8;
        }
        .ar-reticle {
            position: absolute;
            top: 36%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 130px;
            height: 130px;
            border: 1px dashed rgba(212, 160, 86, 0.65);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            pointer-events: none;
        }
        .ar-reticle-dot {
            width: 6px;
            height: 6px;
            border-radius: 50%;
            background: var(--brass);
            box-shadow: 0 0 12px var(--brass);
        }
        .ar-telemetry-tag {
            position: absolute;
            top: 22%;
            right: 18px;
            background: rgba(12, 11, 9, 0.88);
            backdrop-filter: blur(8px);
            border: 1px solid var(--border-brass);
            padding: 8px 12px;
            border-radius: 4px;
        }
        .ar-telemetry-tag span {
            display: block;
            font-family: 'JetBrains Mono', monospace;
            font-size: 10px;
            color: var(--brass);
            text-transform: uppercase;
        }
        .ar-telemetry-tag strong {
            font-size: 12px;
            color: var(--parchment);
            font-weight: 600;
        }
        .ar-overlay-card {
            position: absolute;
            bottom: 14px;
            left: 14px;
            right: 14px;
            background: rgba(12, 11, 9, 0.92);
            backdrop-filter: blur(12px);
            border: 1px solid var(--border-subtle);
            padding: 16px;
            border-radius: 6px;
        }
        .ar-overlay-meta {
            display: flex;
            justify-content: space-between;
            font-family: 'JetBrains Mono', monospace;
            font-size: 10px;
            color: var(--brass);
            text-transform: uppercase;
            margin-bottom: 4px;
        }
        .ar-overlay-title {
            font-family: 'Cormorant Garamond', serif;
            font-size: 21px;
            font-weight: 600;
            color: var(--parchment);
            line-height: 1.2;
        }
        .ar-overlay-footer {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
            margin-top: 6px;
        }
        .ar-overlay-sub {
            font-size: 12px;
            color: var(--text-muted);
        }
        .ar-overlay-cta {
            font-family: 'JetBrains Mono', monospace;
            font-size: 10.5px;
            color: var(--brass);
            text-transform: uppercase;
            letter-spacing: 0.08em;
            white-space: nowrap;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }

        /* ── Section Shared Headers ─────────────────────── */
        section {
            padding: 96px 0;
            border-bottom: 1px solid var(--border-subtle);
        }
        .section-index {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            text-transform: uppercase;
            letter-spacing: 0.16em;
            color: var(--brass);
            margin-bottom: 10px;
        }
        .section-heading {
            font-family: 'Cormorant Garamond', serif;
            font-size: clamp(32px, 4vw, 48px);
            font-weight: 600;
            line-height: 1.1;
            color: var(--parchment);
        }
        .section-desc {
            color: var(--text-muted);
            font-size: 15px;
            max-width: 480px;
            margin-top: 12px;
        }

        /* ── 01 / Capabilities (Architectural Hairline Grid) ─ */
        .capabilities-layout {
            display: grid;
            grid-template-columns: 0.38fr 0.62fr;
            gap: 48px;
            align-items: start;
        }
        .capabilities-matrix {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            background: var(--border-subtle);
            gap: 1px;
            border: 1px solid var(--border-subtle);
        }
        .cap-cell {
            background: var(--bg-obsidian);
            padding: 34px 30px;
            transition: background 0.25s;
        }
        .cap-cell:hover {
            background: var(--bg-surface);
        }
        .cap-top {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 18px;
            color: var(--brass);
        }
        .cap-code {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            letter-spacing: 0.08em;
        }
        .cap-cell h3 {
            font-family: 'Cormorant Garamond', serif;
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 8px;
            color: var(--parchment);
        }
        .cap-cell p {
            font-size: 13.5px;
            color: var(--text-muted);
            line-height: 1.65;
        }

        /* ── 02 / Featured Landmarks (Balanced Editorial Bento) ── */
        .section-top-bar {
            display: flex;
            align-items: flex-end;
            justify-content: space-between;
            gap: 24px;
            margin-bottom: 48px;
            flex-wrap: wrap;
        }
        .landmarks-bento {
            display: grid;
            grid-template-columns: repeat(12, 1fr);
            gap: 24px;
        }
        .landmark-card {
            grid-column: span 4;
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: 6px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            transition: border-color 0.25s, transform 0.25s;
        }
        .landmark-card.span-12 { grid-column: span 12; }
        .landmark-card.span-8  { grid-column: span 8; }
        .landmark-card.span-6  { grid-column: span 6; }
        .landmark-card.span-4  { grid-column: span 4; }

        .landmark-card:hover {
            border-color: var(--border-brass);
            transform: translateY(-3px);
        }
        .landmark-media {
            position: relative;
            height: 220px;
            background: var(--bg-elevated);
            overflow: hidden;
            border-bottom: 1px solid var(--border-subtle);
        }
        .landmark-card.spotlight .landmark-media {
            height: 290px;
        }
        .landmark-media img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            transition: transform 0.5s ease;
        }
        .landmark-card:hover .landmark-media img {
            transform: scale(1.04);
        }
        .landmark-placeholder {
            width: 100%;
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: rgba(212, 160, 86, 0.35);
            background: radial-gradient(circle at center, rgba(212, 160, 86, 0.1), transparent 70%);
        }
        .archive-tag {
            position: absolute;
            top: 14px;
            left: 14px;
            background: rgba(12, 11, 9, 0.88);
            backdrop-filter: blur(8px);
            border: 1px solid var(--border-subtle);
            color: var(--brass);
            font-family: 'JetBrains Mono', monospace;
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            padding: 5px 10px;
            border-radius: 3px;
        }
        .landmark-content {
            padding: 26px;
            display: flex;
            flex-direction: column;
            flex: 1;
            justify-content: space-between;
        }
        .landmark-meta-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            color: var(--brass);
            text-transform: uppercase;
            letter-spacing: 0.08em;
            margin-bottom: 10px;
        }
        .landmark-title {
            font-family: 'Cormorant Garamond', serif;
            font-size: 25px;
            font-weight: 600;
            line-height: 1.2;
            color: var(--parchment);
            margin-bottom: 10px;
        }
        .landmark-card.spotlight .landmark-title {
            font-size: 31px;
        }
        .landmark-desc {
            font-size: 13.5px;
            color: var(--text-muted);
            line-height: 1.65;
            display: -webkit-box;
            -webkit-line-clamp: 3;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }
        .landmark-footer {
            margin-top: 20px;
            padding-top: 14px;
            border-top: 1px solid var(--border-subtle);
            display: flex;
            align-items: center;
            justify-content: space-between;
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            color: var(--text-muted);
        }
        .ar-launch-link {
            color: var(--parchment);
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: color 0.2s;
        }
        .ar-launch-link:hover { color: var(--brass); }

        /* ── 03 / Municipalities Index Strip ────────────── */
        .muni-directory {
            border-top: 1px solid var(--border-subtle);
            margin-top: 40px;
        }
        .muni-row {
            display: grid;
            grid-template-columns: 60px 1.5fr 1fr auto;
            align-items: center;
            padding: 22px 16px;
            border-bottom: 1px solid var(--border-subtle);
            transition: background 0.2s, padding-left 0.2s;
        }
        .muni-row:hover {
            background: rgba(243, 239, 230, 0.025);
            padding-left: 24px;
        }
        .muni-idx {
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            color: var(--text-muted);
        }
        .muni-name {
            font-family: 'Cormorant Garamond', serif;
            font-size: 28px;
            font-weight: 600;
            color: var(--parchment);
        }
        .muni-row:hover .muni-name { color: var(--brass); }
        .muni-prov {
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.08em;
        }
        .muni-badge {
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            color: var(--brass);
            border: 1px solid var(--border-brass);
            background: rgba(212, 160, 86, 0.06);
            padding: 5px 12px;
            border-radius: 3px;
        }

        /* ── 04 / Download Field Box ────────────────────── */
        .cta-banner {
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: 8px;
            padding: 56px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 40px;
            flex-wrap: wrap;
        }
        .cta-copy { max-width: 560px; }
        .cta-specs {
            margin-top: 16px;
            font-family: 'JetBrains Mono', monospace;
            font-size: 11px;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.08em;
        }

        /* ── Footer ─────────────────────────────────────── */
        footer {
            padding: 40px 0;
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            color: var(--text-muted);
        }
        .footer-inner {
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 16px;
        }
        .footer-links {
            display: flex;
            gap: 24px;
        }
        .footer-links a {
            color: var(--text-muted);
            text-decoration: none;
            transition: color 0.2s;
        }
        .footer-links a:hover { color: var(--brass); }

        .empty-state {
            grid-column: 1 / -1;
            padding: 56px;
            text-align: center;
            border: 1px dashed var(--border-subtle);
            color: var(--text-muted);
        }

        /* ── Responsive Breakpoints ─────────────────────── */
        @media (max-width: 992px) {
            .hero-grid,
            .capabilities-layout {
                grid-template-columns: 1fr;
            }
            .landmark-card,
            .landmark-card.span-8,
            .landmark-card.span-6,
            .landmark-card.span-4 {
                grid-column: span 6;
            }
            .landmark-card.span-12 {
                grid-column: span 12;
            }
        }
        @media (max-width: 720px) {
            .container, .nav-inner { padding: 0 20px; }
            .nav-links { display: none; }
            .capabilities-matrix { grid-template-columns: 1fr; }
            .landmark-card,
            .landmark-card.span-12,
            .landmark-card.span-8,
            .landmark-card.span-6,
            .landmark-card.span-4 {
                grid-column: span 12;
            }
            .muni-row {
                grid-template-columns: 40px 1fr auto;
            }
            .muni-prov { display: none; }
            .cta-banner { padding: 32px 24px; }
        }
    </style>
</head>
<body>

    <!-- ── Navbar ─────────────────────────────────── -->
    <nav>
        <div class="nav-inner">
            <a href="/" class="nav-logo">
                <span class="nav-logo-mark">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75">
                        <path d="M4 21V10a8 8 0 0 1 16 0v11"/>
                        <path d="M9 21v-6a3 3 0 0 1 6 0v6"/>
                        <path d="M2 6V3h3M22 6V3h-3"/>
                    </svg>
                </span>
                <span class="nav-logo-text">Daan<span>AR</span></span>
            </a>

            <ul class="nav-links">
                <li><a href="#features">Capabilities</a></li>
                <li><a href="#landmarks">Heritage Archive</a></li>
                <li><a href="#municipalities">Municipalities</a></li>
                <li><a href="#download">Field APK</a></li>
            </ul>

            <a href="/admin" class="nav-admin">
                <span>Admin Portal</span>
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M5 12h14M12 5l7 7-7 7"/>
                </svg>
            </a>
        </div>
    </nav>

    <!-- ── Hero ──────────────────────────────────── -->
    @php
        $heroLandmark = $featured->first();
        $heroArUrl = $heroLandmark ? route('ar.landmark', $heroLandmark->id) : '#landmarks';
    @endphp
    <section class="hero">
        <div class="container hero-grid">
            <!-- Left Column: Editorial Introduction -->
            <div>
                <div class="eyebrow-pill">
                    <span class="pulse-dot"></span>
                    <span class="eyebrow-text">Pangasinan Cultural Field Guide</span>
                </div>

                <h1>
                    Walk through centuries of <em>living architecture.</em>
                </h1>

                <p class="hero-lead">
                    Navigate the Spanish colonial churches and ancestral landmarks of Pangasinan. DaanAR layers historical chronicles, interactive in-app 3D models, and real-time turn-by-turn routing directly onto your mobile device.
                </p>

                <div class="hero-actions">
                    <a href="#download" class="btn-brass">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
                        </svg>
                        <span>Download Field APK</span>
                    </a>
                    <a href="#landmarks" class="btn-outline">
                        <span>Browse Documented Sites</span>
                    </a>
                </div>

                <div class="hero-meta-strip">
                    <div>
                        <div class="meta-label">Documented Sites</div>
                        <div class="meta-value">{{ $featured->count() }} Landmarks</div>
                    </div>
                    <div>
                        <div class="meta-label">Coverage Area</div>
                        <div class="meta-value">{{ $municipalities->count() }} Municipalities</div>
                    </div>
                    <div>
                        <div class="meta-label">Telemetry Mode</div>
                        <div class="meta-value">GPS + In-App AR</div>
                    </div>
                </div>
            </div>

            <!-- Right Column: Interactive Live AR Viewfinder Preview -->
            <a href="{{ $heroArUrl }}" class="ar-viewport hud-frame" title="Click to launch live 3D & AR preview">
                <div class="ar-hud-bar">
                    <span style="color: var(--brass);">● AR VIEWPORT ACTIVE</span>
                    <span>PANGASINAN • 16.04° N, 120.33° E</span>
                </div>
                <div class="ar-screen">
                    @if($heroLandmark && $heroLandmark->hero_image)
                        <img src="{{ asset('storage/' . $heroLandmark->hero_image) }}" alt="{{ $heroLandmark->name }}">
                    @else
                        <div class="landmark-placeholder">
                            <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
                                <path d="M12 3v3m0 0L7 11h10l-5-5zm-7 8v10h14V11M9 21v-5a3 3 0 0 1 6 0v5"/>
                            </svg>
                        </div>
                    @endif

                    <div class="ar-reticle">
                        <div class="ar-reticle-dot"></div>
                    </div>

                    <div class="ar-telemetry-tag">
                        <span>{{ $heroLandmark->era ?? 'Spanish Colonial Era' }}</span>
                        <strong>3D Spatial Anchor Ready</strong>
                    </div>

                    <div class="ar-overlay-card">
                        <div class="ar-overlay-meta">
                            <span>TARGET LOCKED • 100M GEOFENCE</span>
                            <span>{{ $heroLandmark->municipality->name ?? 'Pangasinan' }}</span>
                        </div>
                        <div class="ar-overlay-title">
                            {{ $heroLandmark->name ?? 'Minor Basilica of Our Lady of Manaoag' }}
                        </div>
                        <div class="ar-overlay-footer">
                            <span class="ar-overlay-sub">
                                Tap to inspect live 3D &amp; AR model
                            </span>
                            <span class="ar-overlay-cta">
                                Launch 3D / AR
                                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M7 17L17 7M7 7h10v10"/>
                                </svg>
                            </span>
                        </div>
                    </div>
                </div>
            </a>
        </div>
    </section>

    <!-- ── 01 / Capabilities ─────────────────────── -->
    <section id="features">
        <div class="container capabilities-layout">
            <div>
                <div class="section-index">01 / Field Capabilities</div>
                <h2 class="section-heading">Engineered for on-foot historical discovery.</h2>
                <p class="section-desc">
                    Designed for tourists, students, and educators exploring Pangasinan’s heritage towns in person or virtually.
                </p>
            </div>

            <div class="capabilities-matrix">
                <div class="cap-cell">
                    <div class="cap-top">
                        <span class="cap-code">SYS.01</span>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21"/>
                            <line x1="9" y1="3" x2="9" y2="18"/><line x1="15" y1="6" x2="15" y2="21"/>
                        </svg>
                    </div>
                    <h3>Spatial Heritage Map</h3>
                    <p>Locate documented churches, civic plazas, and ancestral structures on a live map filtered by municipality or architectural category.</p>
                </div>

                <div class="cap-cell">
                    <div class="cap-top">
                        <span class="cap-code">SYS.02</span>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <polygon points="12 2 19 21 12 17 5 21 12 2"/>
                        </svg>
                    </div>
                    <h3>Turn-by-Turn Routing</h3>
                    <p>Real-time walking and driving navigation between municipalities with automatic route recalculation when you detour off course.</p>
                </div>

                <div class="cap-cell">
                    <div class="cap-top">
                        <span class="cap-code">SYS.03</span>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2"/>
                            <circle cx="12" cy="12" r="3"/>
                        </svg>
                    </div>
                    <h3>In-App 3D &amp; Camera AR</h3>
                    <p>Inspect interactive 3D landmark reconstructions directly inside the app and project full-scale models into your physical space via ARCore.</p>
                </div>

                <div class="cap-cell">
                    <div class="cap-top">
                        <span class="cap-code">SYS.04</span>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <circle cx="12" cy="10" r="3"/>
                            <path d="M12 21.7C17.3 17 20 13 20 10a8 8 0 1 0-16 0c0 3 2.7 7 8 11.7z"/>
                        </svg>
                    </div>
                    <h3>100m Geofence &amp; AR Alerts</h3>
                    <p>Automatically verifies on-site visits within a 100-meter GPS geofence and triggers an AR launch prompt within 50 meters of arrival.</p>
                </div>

                <div class="cap-cell">
                    <div class="cap-top">
                        <span class="cap-code">SYS.05</span>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
                            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
                        </svg>
                    </div>
                    <h3>Archival Chronicles</h3>
                    <p>Read curated historical accounts detailing Dominican missions, Baroque stone masonry, and local oral histories.</p>
                </div>

                <div class="cap-cell">
                    <div class="cap-top">
                        <span class="cap-code">SYS.06</span>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
                        </svg>
                    </div>
                    <h3>Offline Field Cache</h3>
                    <p>Previously loaded landmark profiles and coordinates stay cached on your device for areas with intermittent cellular data.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- ── 02 / Featured Landmarks ───────────────── -->
    <section id="landmarks">
        <div class="container">
            <div class="section-top-bar">
                <div>
                    <div class="section-index">02 / Curated Archive</div>
                    <h2 class="section-heading">Documented Heritage Sites</h2>
                </div>
                <a href="/api/v1/landmarks?per_page=100" class="btn-outline" style="padding: 10px 18px; font-size: 12px;">
                    <span class="font-mono">JSON ARCHIVE FEED</span>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M5 12h14M12 5l7 7-7 7"/>
                    </svg>
                </a>
            </div>

            @php
                $totalFeatured = $featured->count();
            @endphp
            <div class="landmarks-bento">
                @forelse($featured as $landmark)
                @php
                    // Balance 12-column Bento rows cleanly for any landmark count
                    $isSpotlight = $loop->first && $totalFeatured !== 3 && $totalFeatured !== 6;
                    if ($totalFeatured === 1) {
                        $spanClass = 'span-12 spotlight';
                    } elseif ($totalFeatured === 3 || $totalFeatured === 6) {
                        $spanClass = 'span-4';
                    } elseif ($totalFeatured === 4) {
                        $spanClass = $loop->first ? 'span-8 spotlight' : ($loop->iteration === 2 ? 'span-4' : 'span-6');
                    } else {
                        $spanClass = $isSpotlight ? 'span-8 spotlight' : 'span-4';
                    }
                @endphp
                <article class="landmark-card {{ $spanClass }}">
                    <div class="landmark-media">
                        @if($landmark->hero_image)
                            <img src="{{ asset('storage/' . $landmark->hero_image) }}" alt="{{ $landmark->name }}" loading="lazy">
                        @else
                            <div class="landmark-placeholder">
                                <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2">
                                    <path d="M4 21V10a8 8 0 0 1 16 0v11M9 21v-6a3 3 0 0 1 6 0v6"/>
                                </svg>
                            </div>
                        @endif
                        <span class="archive-tag">
                            ARCHIVE NO. {{ str_pad($loop->iteration, 2, '0', STR_PAD_LEFT) }} • {{ strtoupper($landmark->category) }}
                        </span>
                    </div>

                    <div class="landmark-content">
                        <div>
                            <div class="landmark-meta-row">
                                <span>{{ $landmark->municipality->name ?? 'Pangasinan' }}</span>
                                @if($landmark->era)
                                    <span>{{ $landmark->era }}</span>
                                @endif
                            </div>
                            <h3 class="landmark-title">{{ $landmark->name }}</h3>
                            <p class="landmark-desc">{{ $landmark->short_description ?: $landmark->description }}</p>
                        </div>

                        <div class="landmark-footer">
                            <span>ID #{{ str_pad($landmark->id, 3, '0', STR_PAD_LEFT) }}</span>
                            <a href="{{ route('ar.landmark', $landmark->id) }}" class="ar-launch-link">
                                <span>Launch WebAR</span>
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M7 17L17 7M7 7h10v10"/>
                                </svg>
                            </a>
                        </div>
                    </div>
                </article>
                @empty
                <div class="empty-state">
                    <p class="font-serif" style="font-size: 24px; margin-bottom: 8px;">No landmarks indexed yet.</p>
                    <p style="font-size: 14px;">Add heritage sites via the <a href="/admin" style="color: var(--brass);">Admin Portal</a>.</p>
                </div>
                @endforelse
            </div>
        </div>
    </section>

    <!-- ── 03 / Municipalities Directory ─────────── -->
    <section id="municipalities">
        <div class="container">
            <div>
                <div class="section-index">03 / Coverage Territory</div>
                <h2 class="section-heading">Municipalities Index</h2>
                <p class="section-desc">
                    DaanAR currently maintains verified GPS boundaries and historical records across {{ $municipalities->count() }} municipalities in Pangasinan.
                </p>
            </div>

            <div class="muni-directory">
                @foreach($municipalities as $municipality)
                <div class="muni-row">
                    <span class="muni-idx">{{ str_pad($loop->iteration, 2, '0', STR_PAD_LEFT) }}</span>
                    <span class="muni-name">{{ $municipality->name }}</span>
                    <span class="muni-prov">{{ $municipality->province }}</span>
                    <span class="muni-badge">
                        {{ $municipality->landmarks_count }} {{ $municipality->landmarks_count == 1 ? 'SITE' : 'SITES' }}
                    </span>
                </div>
                @endforeach
            </div>
        </div>
    </section>

    <!-- ── 04 / Download Field App CTA ───────────── -->
    <section id="download" style="border-bottom: none;">
        <div class="container">
            <div class="cta-banner hud-frame">
                <div class="cta-copy">
                    <div class="section-index">04 / Field Deployment</div>
                    <h2 class="section-heading">Ready to step onto the plaza?</h2>
                    <p class="section-desc">
                        Install the DaanAR Android application to unlock in-app 3D &amp; camera AR overlays, turn-by-turn heritage routing, and 100-meter GPS geofence arrival alerts across Pangasinan.
                    </p>
                    <div class="cta-specs">
                        SYS REQ: ANDROID 8.0+ &nbsp;·&nbsp; CAMERA &amp; GPS PERMISSIONS REQUIRED
                    </div>
                </div>

                <a href="#" class="btn-brass" id="download-btn">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
                    </svg>
                    <span>Download DaanAR (.APK)</span>
                </a>
            </div>
        </div>
    </section>

    <!-- ── Footer ────────────────────────────────── -->
    <footer>
        <div class="container footer-inner">
            <div>DaanAR &nbsp;·&nbsp; Pangasinan Cultural Heritage Navigation</div>
            <div class="footer-links">
                <span>© {{ date('Y') }} DaanAR</span>
                <a href="{{ route('ar.test') }}">AR Camera Test</a>
                <a href="/admin">Admin Portal</a>
            </div>
        </div>
    </footer>

</body>
</html>
