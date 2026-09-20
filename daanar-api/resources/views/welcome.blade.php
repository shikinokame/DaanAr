<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="dark">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DaanAR - Augmented Reality Navigation System</title>
    <link rel="icon" type="image/png" href="{{ asset('logo.png') }}">
    
    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Outfit:wght@400;600;700;800&display=swap" rel="stylesheet">

    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        :root {
            --bg-color: #080c14;
            --card-bg: rgba(16, 23, 38, 0.75);
            --card-border: rgba(255, 255, 255, 0.08);
            --primary-amber: #f59e0b;
            --primary-amber-hover: #d97706;
            --gold-accent: #d4a853;
            --text-primary: #f9fafb;
            --text-muted: #9ca3af;
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-primary);
            min-height: 100vh;
            overflow-x: hidden;
            position: relative;
            line-height: 1.6;
        }

        /* Ambient Watermark Background */
        .watermark-bg {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: min(85vw, 780px);
            height: min(85vw, 780px);
            background-image: url('{{ asset('logo.png') }}');
            background-repeat: no-repeat;
            background-position: center;
            background-size: contain;
            opacity: 0.15;
            pointer-events: none;
            z-index: 0;
            filter: drop-shadow(0 0 60px rgba(0, 0, 0, 0.9));
        }

        .ambient-radial {
            position: fixed;
            inset: 0;
            background: radial-gradient(circle at center, rgba(16, 24, 40, 0.4) 0%, rgba(6, 9, 15, 0.92) 100%);
            pointer-events: none;
            z-index: 1;
        }

        /* Container */
        .page-wrapper {
            position: relative;
            z-index: 10;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }

        .container {
            max-width: 1180px;
            margin: 0 auto;
            padding: 0 1.5rem;
            width: 100%;
        }

        /* Navigation */
        nav {
            padding: 1.5rem 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.06);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            background: rgba(8, 12, 20, 0.6);
            position: sticky;
            top: 0;
            z-index: 50;
        }

        .nav-inner {
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .brand-badge {
            display: flex;
            align-items: center;
            gap: 0.85rem;
            text-decoration: none;
            color: #fff;
        }

        .brand-logo-img {
            width: 44px;
            height: 44px;
            border-radius: 50%;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
            border: 1.5px solid rgba(212, 168, 83, 0.4);
        }

        .brand-title {
            font-family: 'Outfit', sans-serif;
            font-size: 1.4rem;
            font-weight: 800;
            letter-spacing: 0.04em;
            background: linear-gradient(135deg, #ffffff 40%, var(--gold-accent) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .nav-actions {
            display: flex;
            align-items: center;
            gap: 1rem;
        }

        .btn-portal {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.6rem 1.25rem;
            border-radius: 0.625rem;
            font-weight: 600;
            font-size: 0.9rem;
            text-decoration: none;
            background: linear-gradient(135deg, var(--primary-amber) 0%, var(--primary-amber-hover) 100%);
            color: #ffffff;
            box-shadow: 0 4px 14px rgba(245, 158, 11, 0.35);
            transition: all 0.25s ease;
        }

        .btn-portal:hover {
            transform: translateY(-1px);
            box-shadow: 0 6px 20px rgba(245, 158, 11, 0.5);
        }

        /* Hero Section */
        .hero {
            padding: 5rem 0 3rem 0;
            text-align: center;
        }

        .badge-pill {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.35rem 1rem;
            border-radius: 9999px;
            background: rgba(245, 158, 11, 0.12);
            border: 1px solid rgba(245, 158, 11, 0.3);
            color: var(--primary-amber);
            font-size: 0.85rem;
            font-weight: 600;
            letter-spacing: 0.05em;
            margin-bottom: 1.5rem;
            text-transform: uppercase;
        }

        .hero-title {
            font-family: 'Outfit', sans-serif;
            font-size: clamp(2.5rem, 5vw, 4rem);
            font-weight: 800;
            line-height: 1.15;
            letter-spacing: -0.02em;
            margin-bottom: 1.25rem;
        }

        .hero-title span {
            background: linear-gradient(135deg, #ffffff 30%, var(--gold-accent) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .hero-subtitle {
            font-size: clamp(1.05rem, 2vw, 1.25rem);
            color: var(--text-muted);
            max-width: 680px;
            margin: 0 auto 2.5rem auto;
        }

        .hero-buttons {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 1.25rem;
            flex-wrap: wrap;
        }

        .btn-secondary {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.75rem 1.6rem;
            border-radius: 0.625rem;
            font-weight: 600;
            font-size: 0.95rem;
            text-decoration: none;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.12);
            color: #fff;
            backdrop-filter: blur(10px);
            transition: all 0.25s ease;
        }

        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.1);
            border-color: rgba(255, 255, 255, 0.25);
            transform: translateY(-1px);
        }

        /* Features Grid */
        .features-section {
            padding: 4rem 0;
        }

        .grid-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 1.5rem;
        }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 1rem;
            padding: 2rem;
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            transition: transform 0.25s ease, border-color 0.25s ease;
        }

        .card:hover {
            transform: translateY(-3px);
            border-color: rgba(245, 158, 11, 0.35);
        }

        .card-icon {
            width: 48px;
            height: 48px;
            border-radius: 0.75rem;
            background: rgba(245, 158, 11, 0.12);
            border: 1px solid rgba(245, 158, 11, 0.25);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.4rem;
            margin-bottom: 1.25rem;
        }

        .card-title {
            font-family: 'Outfit', sans-serif;
            font-size: 1.25rem;
            font-weight: 700;
            margin-bottom: 0.6rem;
            color: #fff;
        }

        .card-desc {
            font-size: 0.92rem;
            color: var(--text-muted);
            line-height: 1.55;
        }

        /* Footer */
        footer {
            padding: 2.5rem 0;
            border-top: 1px solid rgba(255, 255, 255, 0.06);
            text-align: center;
            font-size: 0.88rem;
            color: var(--text-muted);
        }
    </style>
</head>
<body>

    <!-- Watermark Logo Centered Background -->
    <div class="watermark-bg"></div>
    <div class="ambient-radial"></div>

    <div class="page-wrapper">
        <!-- Navbar -->
        <nav>
            <div class="container nav-inner">
                <a href="{{ url('/') }}" class="brand-badge">
                    <img src="{{ asset('logo.png') }}" alt="DaanAR Logo" class="brand-logo-img">
                    <span class="brand-title">DaanAR</span>
                </a>
                <div class="nav-actions">
                    <a href="{{ url('/admin/login') }}" class="btn-portal">
                        <span>Admin Portal</span>
                        <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"/>
                        </svg>
                    </a>
                </div>
            </div>
        </nav>

        <!-- Hero Section -->
        <main class="hero container">
            <div class="badge-pill">
                🏛️ Pangasinan Historical Heritage & AR Navigation
            </div>
            
            <h1 class="hero-title">
                Heritage in Your Hands with <span>DaanAR</span>
            </h1>
            
            <p class="hero-subtitle">
                An Augmented Reality Navigation and Heritage Discovery System for historical landmarks, cultural churches, and curated trails across the province of Pangasinan.
            </p>

            <div class="hero-buttons">
                <a href="{{ url('/admin/login') }}" class="btn-portal" style="padding: 0.85rem 1.8rem; font-size: 1rem;">
                    <span>Sign In to Admin Panel</span>
                    <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"/>
                    </svg>
                </a>
                <a href="{{ route('ar.test') }}" class="btn-secondary" style="padding: 0.85rem 1.8rem; font-size: 1rem;">
                    <span>📷 Test WebAR Camera</span>
                </a>
            </div>

            <!-- Features Grid -->
            <section class="features-section">
                <div class="grid-cards">
                    <div class="card">
                        <div class="card-icon">🏛️</div>
                        <h3 class="card-title">Historical Landmarks</h3>
                        <p class="card-desc">Curated database of Pangasinan's centuries-old churches, heritage shrines, and provincial monuments.</p>
                    </div>

                    <div class="card">
                        <div class="card-icon">🧭</div>
                        <h3 class="card-title">AR Waypoints</h3>
                        <p class="card-desc">Real-time augmented reality visual markers pointing visitors directly to destinations via mobile camera.</p>
                    </div>

                    <div class="card">
                        <div class="card-icon">🗺️</div>
                        <h3 class="card-title">Heritage Trails</h3>
                        <p class="card-desc">Pre-designed walking and travel itineraries connecting historical sites across Pangasinan municipalities.</p>
                    </div>

                    <div class="card">
                        <div class="card-icon">⚡</div>
                        <h3 class="card-title">Offline Ready</h3>
                        <p class="card-desc">Persistent local cache ensuring travelers can browse landmarks and trails without active cellular data.</p>
                    </div>
                </div>
            </section>
        </main>

        <!-- Footer -->
        <footer>
            <div class="container">
                <p>&copy; {{ date('Y') }} DaanAR — An Augmented Reality Navigation System for Historical Landmarks in Pangasinan.</p>
                <p style="margin-top: 0.25rem; font-size: 0.8rem; opacity: 0.7;">Thesis & Capstone Research Project</p>
            </div>
        </footer>
    </div>

</body>
</html>
