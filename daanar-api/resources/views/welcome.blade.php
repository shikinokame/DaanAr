<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DaanAR — Augmented Reality Heritage Navigation</title>
    <meta name="description" content="Explore the heritage landmarks of Pangasinan through Augmented Reality. Navigate, discover, and experience history like never before with DaanAR.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Playfair+Display:wght@700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --dark:       #0b0f19;
            --dark-card:  #131929;
            --dark-border:#1e2a40;
            --gold:       #D4A853;
            --gold-light: #e8c27a;
            --green:      #1B4332;
            --green-mid:  #2D6A4F;
            --text:       #e2e8f0;
            --text-muted: #94a3b8;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        html { scroll-behavior: smooth; }

        body {
            background-color: var(--dark);
            color: var(--text);
            font-family: 'Inter', sans-serif;
            overflow-x: hidden;
        }

        /* ── Scrollbar ──────────────────────────────────── */
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: var(--dark); }
        ::-webkit-scrollbar-thumb { background: var(--gold); border-radius: 3px; }

        /* ── Navbar ─────────────────────────────────────── */
        nav {
            position: fixed;
            top: 0; left: 0; right: 0;
            z-index: 100;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 18px 48px;
            background: rgba(11,15,25,0.8);
            backdrop-filter: blur(16px);
            border-bottom: 1px solid var(--dark-border);
        }
        .nav-logo {
            font-family: 'Playfair Display', serif;
            font-size: 24px;
            font-weight: 800;
            color: var(--gold);
            letter-spacing: 1px;
            text-decoration: none;
        }
        .nav-logo span { color: var(--text); font-weight: 300; }
        .nav-links { display: flex; gap: 32px; list-style: none; }
        .nav-links a {
            color: var(--text-muted);
            text-decoration: none;
            font-size: 14px;
            font-weight: 500;
            transition: color 0.2s;
        }
        .nav-links a:hover { color: var(--gold); }
        .nav-admin {
            background: rgba(212,168,83,0.12);
            border: 1px solid rgba(212,168,83,0.4);
            color: var(--gold);
            padding: 8px 20px;
            border-radius: 8px;
            text-decoration: none;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.2s;
        }
        .nav-admin:hover {
            background: rgba(212,168,83,0.25);
        }

        /* ── Hero ───────────────────────────────────────── */
        .hero {
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            text-align: center;
            padding: 120px 24px 80px;
            position: relative;
            overflow: hidden;
        }
        .hero::before {
            content: '';
            position: absolute;
            inset: 0;
            background:
                radial-gradient(ellipse 60% 50% at 50% 0%, rgba(27,67,50,0.35) 0%, transparent 70%),
                radial-gradient(ellipse 40% 30% at 80% 80%, rgba(212,168,83,0.08) 0%, transparent 60%);
            pointer-events: none;
        }
        .hero-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(212,168,83,0.12);
            border: 1px solid rgba(212,168,83,0.35);
            color: var(--gold);
            font-size: 13px;
            font-weight: 600;
            padding: 6px 16px;
            border-radius: 20px;
            margin-bottom: 28px;
            letter-spacing: 0.5px;
        }
        .hero h1 {
            font-family: 'Playfair Display', serif;
            font-size: clamp(42px, 7vw, 80px);
            font-weight: 800;
            line-height: 1.1;
            margin-bottom: 24px;
        }
        .hero h1 .highlight {
            background: linear-gradient(135deg, var(--gold), var(--gold-light));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .hero p {
            font-size: clamp(16px, 2.5vw, 20px);
            color: var(--text-muted);
            max-width: 620px;
            line-height: 1.7;
            margin-bottom: 40px;
        }
        .hero-cta {
            display: flex;
            gap: 16px;
            flex-wrap: wrap;
            justify-content: center;
        }
        .btn-primary {
            background: linear-gradient(135deg, var(--gold), #c8922a);
            color: #0b0f19;
            padding: 14px 32px;
            border-radius: 10px;
            font-size: 15px;
            font-weight: 700;
            text-decoration: none;
            transition: all 0.2s;
            box-shadow: 0 4px 20px rgba(212,168,83,0.3);
        }
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 28px rgba(212,168,83,0.45);
        }
        .btn-secondary {
            background: transparent;
            color: var(--text);
            padding: 14px 32px;
            border-radius: 10px;
            font-size: 15px;
            font-weight: 600;
            text-decoration: none;
            border: 1px solid var(--dark-border);
            transition: all 0.2s;
        }
        .btn-secondary:hover {
            border-color: var(--gold);
            color: var(--gold);
        }
        .hero-stats {
            display: flex;
            gap: 48px;
            margin-top: 64px;
            flex-wrap: wrap;
            justify-content: center;
        }
        .stat { text-align: center; }
        .stat-num {
            font-size: 32px;
            font-weight: 800;
            color: var(--gold);
            font-family: 'Playfair Display', serif;
        }
        .stat-label {
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 4px;
        }

        /* ── Section base ───────────────────────────────── */
        section { padding: 96px 48px; }
        .section-label {
            font-size: 12px;
            font-weight: 700;
            letter-spacing: 2px;
            color: var(--gold);
            text-transform: uppercase;
            margin-bottom: 12px;
        }
        .section-title {
            font-family: 'Playfair Display', serif;
            font-size: clamp(28px, 4vw, 44px);
            font-weight: 800;
            margin-bottom: 16px;
        }
        .section-sub {
            color: var(--text-muted);
            font-size: 16px;
            max-width: 520px;
            line-height: 1.7;
            margin-bottom: 56px;
        }

        /* ── Features ───────────────────────────────────── */
        #features { background: var(--dark-card); }
        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 24px;
            max-width: 1100px;
            margin: 0 auto;
        }
        .feature-card {
            background: var(--dark);
            border: 1px solid var(--dark-border);
            border-radius: 16px;
            padding: 32px;
            transition: all 0.3s;
            position: relative;
            overflow: hidden;
        }
        .feature-card::before {
            content: '';
            position: absolute;
            inset: 0;
            border-radius: 16px;
            background: linear-gradient(135deg, rgba(212,168,83,0.06), transparent);
            opacity: 0;
            transition: opacity 0.3s;
        }
        .feature-card:hover { border-color: rgba(212,168,83,0.4); transform: translateY(-4px); }
        .feature-card:hover::before { opacity: 1; }
        .feature-icon {
            width: 52px; height: 52px;
            background: rgba(212,168,83,0.12);
            border: 1px solid rgba(212,168,83,0.25);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            margin-bottom: 20px;
        }
        .feature-card h3 {
            font-size: 18px;
            font-weight: 700;
            margin-bottom: 10px;
        }
        .feature-card p { color: var(--text-muted); font-size: 14px; line-height: 1.7; }

        /* ── Landmarks ──────────────────────────────────── */
        #landmarks { max-width: 1200px; margin: 0 auto; }
        .landmarks-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            margin-bottom: 40px;
            flex-wrap: wrap;
            gap: 16px;
        }
        .landmarks-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 24px;
        }
        .landmark-card {
            background: var(--dark-card);
            border: 1px solid var(--dark-border);
            border-radius: 20px;
            overflow: hidden;
            transition: all 0.35s;
            cursor: default;
        }
        .landmark-card:hover {
            border-color: rgba(212,168,83,0.4);
            transform: translateY(-6px);
            box-shadow: 0 20px 40px rgba(0,0,0,0.4);
        }
        .landmark-image {
            height: 180px;
            background: linear-gradient(135deg, var(--green), var(--green-mid));
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 48px;
            position: relative;
            overflow: hidden;
        }
        .landmark-image img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            position: absolute;
            inset: 0;
        }
        .landmark-category-badge {
            position: absolute;
            top: 12px;
            left: 12px;
            background: rgba(11,15,25,0.8);
            backdrop-filter: blur(8px);
            border: 1px solid rgba(212,168,83,0.4);
            color: var(--gold);
            font-size: 11px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 20px;
            text-transform: capitalize;
            letter-spacing: 0.5px;
        }
        .landmark-featured-badge {
            position: absolute;
            top: 12px;
            right: 12px;
            background: linear-gradient(135deg, var(--gold), #c8922a);
            color: #0b0f19;
            font-size: 10px;
            font-weight: 800;
            padding: 4px 10px;
            border-radius: 20px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .landmark-body { padding: 24px; }
        .landmark-municipality {
            font-size: 12px;
            color: var(--gold);
            font-weight: 600;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            margin-bottom: 8px;
        }
        .landmark-name {
            font-size: 18px;
            font-weight: 700;
            margin-bottom: 10px;
            line-height: 1.3;
        }
        .landmark-desc {
            color: var(--text-muted);
            font-size: 13px;
            line-height: 1.65;
            display: -webkit-box;
            -webkit-line-clamp: 3;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }
        .landmark-era {
            margin-top: 16px;
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 12px;
            color: var(--text-muted);
        }

        /* Category icon map */
        .cat-church   { background: linear-gradient(135deg, #2c3e50, #4a5568); }
        .cat-park     { background: linear-gradient(135deg, #1B4332, #2D6A4F); }
        .cat-natural  { background: linear-gradient(135deg, #1a3a2a, #2e5f4a); }
        .cat-historical { background: linear-gradient(135deg, #3d2b1f, #5d4037); }
        .cat-cultural { background: linear-gradient(135deg, #2d1b4e, #4a2c7e); }

        /* ── Municipalities ─────────────────────────────── */
        #municipalities { background: var(--dark-card); }
        .municipalities-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 20px;
            max-width: 1100px;
            margin: 0 auto;
        }
        .municipality-card {
            background: var(--dark);
            border: 1px solid var(--dark-border);
            border-radius: 16px;
            padding: 28px 24px;
            text-align: center;
            transition: all 0.3s;
        }
        .municipality-card:hover {
            border-color: rgba(212,168,83,0.4);
            transform: translateY(-4px);
        }
        .municipality-icon {
            width: 56px; height: 56px;
            background: rgba(27,67,50,0.4);
            border: 1px solid rgba(27,67,50,0.8);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            margin: 0 auto 16px;
        }
        .municipality-name {
            font-size: 16px;
            font-weight: 700;
            margin-bottom: 6px;
        }
        .municipality-province {
            font-size: 12px;
            color: var(--text-muted);
            margin-bottom: 12px;
        }
        .municipality-count {
            display: inline-block;
            background: rgba(212,168,83,0.12);
            border: 1px solid rgba(212,168,83,0.3);
            color: var(--gold);
            font-size: 12px;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 20px;
        }

        /* ── Download CTA ───────────────────────────────── */
        #download {
            text-align: center;
            padding: 96px 24px;
            position: relative;
            overflow: hidden;
        }
        #download::before {
            content: '';
            position: absolute;
            inset: 0;
            background: radial-gradient(ellipse 60% 70% at 50% 50%, rgba(27,67,50,0.25) 0%, transparent 70%);
            pointer-events: none;
        }
        .download-box {
            max-width: 640px;
            margin: 0 auto;
            background: var(--dark-card);
            border: 1px solid var(--dark-border);
            border-radius: 24px;
            padding: 56px 48px;
            position: relative;
        }
        .download-box::before {
            content: '';
            position: absolute;
            inset: -1px;
            border-radius: 24px;
            background: linear-gradient(135deg, rgba(212,168,83,0.3), transparent 50%, rgba(27,67,50,0.3));
            z-index: -1;
        }
        .download-box h2 {
            font-family: 'Playfair Display', serif;
            font-size: 32px;
            font-weight: 800;
            margin-bottom: 16px;
        }
        .download-box p {
            color: var(--text-muted);
            font-size: 16px;
            line-height: 1.7;
            margin-bottom: 32px;
        }

        /* ── Footer ─────────────────────────────────────── */
        footer {
            border-top: 1px solid var(--dark-border);
            padding: 40px 48px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 16px;
        }
        .footer-logo {
            font-family: 'Playfair Display', serif;
            font-size: 20px;
            font-weight: 800;
            color: var(--gold);
        }
        .footer-copy { color: var(--text-muted); font-size: 13px; }
        .footer-link { color: var(--gold); text-decoration: none; }

        /* ── Responsive ─────────────────────────────────── */
        @media (max-width: 768px) {
            nav { padding: 16px 20px; }
            .nav-links { display: none; }
            section { padding: 64px 20px; }
            footer { padding: 32px 20px; flex-direction: column; text-align: center; }
            .hero { padding: 100px 20px 60px; }
            .download-box { padding: 36px 24px; }
        }

        /* ── Animations ─────────────────────────────────── */
        @keyframes fadeUp {
            from { opacity: 0; transform: translateY(24px); }
            to   { opacity: 1; transform: translateY(0); }
        }
        .fade-up { animation: fadeUp 0.6s ease both; }
        .fade-up-1 { animation-delay: 0.1s; }
        .fade-up-2 { animation-delay: 0.2s; }
        .fade-up-3 { animation-delay: 0.3s; }
        .fade-up-4 { animation-delay: 0.45s; }

        /* Loading state for empty data */
        .empty-state {
            text-align: center;
            padding: 48px;
            color: var(--text-muted);
            grid-column: 1 / -1;
        }
        .empty-state .icon { font-size: 48px; margin-bottom: 16px; }
    </style>
</head>
<body>

    <!-- ── Navbar ─────────────────────────────────── -->
    <nav>
        <a href="/" class="nav-logo">Daan<span>AR</span></a>
        <ul class="nav-links">
            <li><a href="#features">Features</a></li>
            <li><a href="#landmarks">Landmarks</a></li>
            <li><a href="#municipalities">Municipalities</a></li>
            <li><a href="#download">Get the App</a></li>
        </ul>
        <a href="/admin" class="nav-admin">Admin Panel →</a>
    </nav>

    <!-- ── Hero ──────────────────────────────────── -->
    <section class="hero">
        <div class="hero-badge fade-up">🏛️ Pangasinan Heritage Navigation</div>
        <h1 class="fade-up fade-up-1">
            Discover Heritage<br>Through <span class="highlight">Augmented Reality</span>
        </h1>
        <p class="fade-up fade-up-2">
            Navigate the cultural landmarks of Pangasinan with real-time AR overlays, turn-by-turn directions, and immersive 3D experiences — right on your phone.
        </p>
        <div class="hero-cta fade-up fade-up-3">
            <a href="#download" class="btn-primary">📲 Download DaanAR</a>
            <a href="#landmarks" class="btn-secondary">Explore Landmarks</a>
        </div>
        <div class="hero-stats fade-up fade-up-4">
            <div class="stat">
                <div class="stat-num">{{ $featured->count() }}+</div>
                <div class="stat-label">Featured Landmarks</div>
            </div>
            <div class="stat">
                <div class="stat-num">{{ $municipalities->count() }}</div>
                <div class="stat-label">Municipalities</div>
            </div>
            <div class="stat">
                <div class="stat-num">AR</div>
                <div class="stat-label">Powered Experience</div>
            </div>
        </div>
    </section>

    <!-- ── Features ──────────────────────────────── -->
    <section id="features">
        <div style="max-width:1100px; margin:0 auto;">
            <div class="section-label">What We Offer</div>
            <h2 class="section-title">Everything You Need to Explore</h2>
            <p class="section-sub">A full-featured heritage guide powered by real-time navigation and augmented reality.</p>
            <div class="features-grid">
                <div class="feature-card">
                    <div class="feature-icon">🗺️</div>
                    <h3>Interactive Map</h3>
                    <p>Find all heritage landmarks on a live Google Maps interface. Filter by municipality or category.</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">🧭</div>
                    <h3>Real-Time Navigation</h3>
                    <p>Get turn-by-turn route guidance to any landmark with automatic rerouting when you drift off course.</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">📷</div>
                    <h3>Augmented Reality</h3>
                    <p>Point your camera at a landmark and see 3D overlays, historical info, and immersive AR experiences.</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">🏛️</div>
                    <h3>Heritage Stories</h3>
                    <p>Rich descriptions, historical eras, and cultural context for every landmark in Pangasinan.</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">📍</div>
                    <h3>Proximity Alerts</h3>
                    <p>Get notified when you're within 50 metres of your destination with an AR launch prompt.</p>
                </div>
                <div class="feature-card">
                    <div class="feature-icon">📶</div>
                    <h3>Offline Support</h3>
                    <p>Previously loaded landmarks stay cached so you can browse even with limited connectivity.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- ── Featured Landmarks ────────────────────── -->
    <section id="landmarks" style="padding: 96px 48px;">
        <div class="landmarks-header">
            <div>
                <div class="section-label">Heritage Sites</div>
                <h2 class="section-title">Featured Landmarks</h2>
            </div>
            <a href="/api/v1/landmarks?per_page=100" class="btn-secondary" style="font-size:13px; padding:10px 20px;">
                View All via API →
            </a>
        </div>
        <div class="landmarks-grid">
            @forelse($featured as $landmark)
            <div class="landmark-card">
                <div class="landmark-image cat-{{ $landmark->category }}">
                    @if($landmark->hero_image)
                        <img src="{{ $landmark->hero_image }}" alt="{{ $landmark->name }}" loading="lazy">
                    @else
                        @switch($landmark->category)
                            @case('church')    ⛪ @break
                            @case('park')      🌳 @break
                            @case('natural')   🏖️ @break
                            @case('historical') 🏛️ @break
                            @case('cultural')  🎭 @break
                            @default           📍
                        @endswitch
                    @endif
                    <span class="landmark-category-badge">{{ $landmark->category }}</span>
                    @if($landmark->is_featured)
                        <span class="landmark-featured-badge">✦ Featured</span>
                    @endif
                </div>
                <div class="landmark-body">
                    <div class="landmark-municipality">
                        📍 {{ $landmark->municipality->name ?? 'Pangasinan' }}
                    </div>
                    <div class="landmark-name">{{ $landmark->name }}</div>
                    <div class="landmark-desc">{{ $landmark->short_description ?: $landmark->description }}</div>
                    @if($landmark->era)
                    <div class="landmark-era">
                        🕰️ {{ $landmark->era }}
                    </div>
                    @endif
                </div>
            </div>
            @empty
            <div class="empty-state">
                <div class="icon">🏛️</div>
                <p>No featured landmarks yet. Add some via the <a href="/admin" style="color: var(--gold)">Admin Panel</a>.</p>
            </div>
            @endforelse
        </div>
    </section>

    <!-- ── Municipalities ────────────────────────── -->
    <section id="municipalities">
        <div style="max-width:1100px; margin:0 auto;">
            <div class="section-label">Coverage Area</div>
            <h2 class="section-title">Municipalities</h2>
            <p class="section-sub">DaanAR currently covers {{ $municipalities->count() }} municipalities across Pangasinan province.</p>
            <div class="municipalities-grid">
                @foreach($municipalities as $municipality)
                <div class="municipality-card">
                    <div class="municipality-icon">🏙️</div>
                    <div class="municipality-name">{{ $municipality->name }}</div>
                    <div class="municipality-province">{{ $municipality->province }}</div>
                    <span class="municipality-count">{{ $municipality->landmarks_count }} landmark{{ $municipality->landmarks_count != 1 ? 's' : '' }}</span>
                </div>
                @endforeach
            </div>
        </div>
    </section>

    <!-- ── Download CTA ──────────────────────────── -->
    <section id="download">
        <div class="download-box">
            <h2>Ready to Explore?</h2>
            <p>Download DaanAR on your Android device and start navigating the heritage landmarks of Pangasinan with Augmented Reality.</p>
            <a href="#" class="btn-primary" id="download-btn">📲 Download APK</a>
            <p style="margin-top:16px; font-size:13px; color:var(--text-muted);">
                Android 8.0+ required &nbsp;·&nbsp; Camera permission needed for AR
            </p>
        </div>
    </section>

    <!-- ── Footer ────────────────────────────────── -->
    <footer>
        <div class="footer-logo">DaanAR</div>
        <div class="footer-copy">
            © {{ date('Y') }} DaanAR &nbsp;·&nbsp; Pangasinan Heritage Navigation &nbsp;·&nbsp;
            <a href="/admin" class="footer-link">Admin</a>
        </div>
    </footer>

</body>
</html>
