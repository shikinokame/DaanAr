<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="theme-color" content="#1B4332">
  <title>{{ $landmark->name }} — Interactive 3D & AR Experience</title>

  <!-- Google Model Viewer (3D, Surface Hotspots & Markerless AR) -->
  <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js"></script>

  <style>
    :root {
      --primary: #1B4332;
      --accent: #D4A853;
      --accent-hover: #e0b865;
      --bg-dark: #0b1812;
      --text: #ffffff;
      --text-muted: rgba(255, 255, 255, 0.78);
    }

    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }

    body, html {
      width: 100%;
      height: 100%;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: radial-gradient(circle at 50% 40%, #173628 0%, #08140e 100%);
      color: var(--text);
      transition: background 0.6s ease;
    }

    /* ── Atmosphere & Era Lighting Themes ── */
    body.mode-day {
      background: radial-gradient(circle at 50% 35%, #1e4d38 0%, #091710 100%);
    }
    body.mode-golden {
      background: radial-gradient(circle at 50% 35%, #5c3418 0%, #1f1108 65%, #0c0704 100%);
    }
    body.mode-night {
      background: radial-gradient(circle at 50% 35%, #0f1b2e 0%, #050811 100%);
    }
    body.mode-era {
      background: radial-gradient(circle at 50% 35%, #463521 0%, #1c140b 100%);
    }
    body.mode-era model-viewer {
      filter: sepia(0.72) contrast(1.12) brightness(0.95);
    }
    body.mode-golden model-viewer {
      filter: sepia(0.24) saturate(1.35) contrast(1.06);
    }
    body.mode-night model-viewer {
      filter: brightness(0.78) contrast(1.18) saturate(0.9);
    }

    /* Historical Era Vignette Overlay */
    #era-overlay {
      position: absolute;
      inset: 0;
      pointer-events: none;
      z-index: 45;
      opacity: 0;
      transition: opacity 0.4s ease;
      background:
        radial-gradient(circle at center, transparent 52%, rgba(28, 18, 8, 0.68) 100%),
        repeating-linear-gradient(0deg, rgba(255, 235, 200, 0.03) 0px, rgba(255, 235, 200, 0.03) 1px, transparent 1px, transparent 3px);
    }
    body.mode-era #era-overlay {
      opacity: 1;
    }

    #era-watermark {
      position: absolute;
      top: 72px;
      left: 16px;
      z-index: 80;
      background: rgba(62, 43, 21, 0.88);
      border: 1px solid rgba(212, 168, 83, 0.65);
      color: #f5deb3;
      padding: 5px 12px;
      border-radius: 14px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.6px;
      text-transform: uppercase;
      display: none;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
    }
    body.mode-era #era-watermark {
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }

    #viewer-container {
      width: 100%;
      height: 100%;
      position: relative;
      overflow: hidden;
    }

    model-viewer {
      width: 100%;
      height: 100%;
      background: transparent;
      outline: none;
      --progress-bar-color: transparent;
      --progress-mask: transparent;
      transition: filter 0.45s ease;
    }

    /* ── Interactive 3D Surface Hotspot Pins ── */
    .hotspot-pin {
      width: 34px;
      height: 34px;
      border-radius: 50%;
      border: 2px solid #fff;
      background: linear-gradient(135deg, #D4A853 0%, #9e7322 100%);
      color: #0b1812;
      font-weight: 800;
      font-size: 13px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 0 0 5px rgba(212, 168, 83, 0.32), 0 4px 14px rgba(0, 0, 0, 0.55);
      transition: transform 0.25s ease, background 0.25s ease, box-shadow 0.25s ease, opacity 0.25s ease;
      position: relative;
    }

    .hotspot-pin::after {
      content: '';
      position: absolute;
      inset: -6px;
      border-radius: 50%;
      border: 2px solid rgba(212, 168, 83, 0.75);
      animation: hotspotPulse 2s infinite ease-out;
      pointer-events: none;
    }

    .hotspot-pin.active {
      transform: scale(1.24);
      background: #34D399;
      color: #052e16;
      border-color: #ffffff;
      box-shadow: 0 0 0 7px rgba(52, 211, 153, 0.38), 0 6px 18px rgba(0, 0, 0, 0.65);
    }

    .hotspot-pin.hidden-pin {
      opacity: 0;
      pointer-events: none;
      transform: scale(0.5);
    }

    .hotspot-tag {
      position: absolute;
      bottom: 40px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(11, 24, 18, 0.92);
      border: 1px solid rgba(212, 168, 83, 0.55);
      color: #fff;
      padding: 4px 9px;
      border-radius: 10px;
      font-size: 10.5px;
      font-weight: 700;
      white-space: nowrap;
      pointer-events: none;
      box-shadow: 0 4px 10px rgba(0, 0, 0, 0.45);
    }

    @keyframes hotspotPulse {
      0% { transform: scale(0.88); opacity: 0.95; }
      100% { transform: scale(1.48); opacity: 0; }
    }

    /* ── Top Bar ── */
    .top-bar {
      position: absolute;
      top: env(safe-area-inset-top, 14px);
      left: 14px;
      right: 14px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      z-index: 100;
      pointer-events: none;
    }

    .top-btn {
      pointer-events: auto;
      background: rgba(11, 24, 18, 0.85);
      backdrop-filter: blur(12px);
      border: 1px solid rgba(212, 168, 83, 0.35);
      color: #fff;
      width: 42px;
      height: 42px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
      transition: transform 0.15s ease, background 0.15s ease;
    }

    .top-btn:active {
      transform: scale(0.92);
      background: rgba(27, 67, 50, 0.95);
    }

    .title-pill {
      background: rgba(11, 24, 18, 0.85);
      backdrop-filter: blur(12px);
      border: 1px solid rgba(212, 168, 83, 0.35);
      padding: 8px 18px;
      border-radius: 24px;
      text-align: center;
      max-width: 66%;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
    }

    .title-pill h1 {
      font-size: 14px;
      font-weight: 700;
      color: var(--accent);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .title-pill span {
      font-size: 11px;
      color: var(--text-muted);
      display: block;
    }

    /* ── Floating Right Side Controls ── */
    .controls-stack {
      position: absolute;
      top: 74px;
      right: 14px;
      display: flex;
      flex-direction: column;
      gap: 9px;
      z-index: 90;
    }

    .control-btn {
      background: rgba(11, 24, 18, 0.85);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(212, 168, 83, 0.3);
      color: #fff;
      min-width: 42px;
      height: 42px;
      padding: 0 11px;
      border-radius: 13px;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      font-size: 11.5px;
      font-weight: 700;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      transition: transform 0.15s ease, background 0.15s ease, border-color 0.15s ease;
    }

    .control-btn.active {
      background: var(--accent);
      color: #0b1812;
      border-color: var(--accent);
    }

    .control-btn.tour-active {
      background: linear-gradient(135deg, #34D399 0%, #10B981 100%);
      color: #052e16;
      border-color: #6EE7B7;
      box-shadow: 0 0 16px rgba(52, 211, 153, 0.5);
    }

    .control-btn:active {
      transform: scale(0.92);
    }

    /* ── Atmosphere & Lighting Pill Bar (Left/Top-Center) ── */
    .lighting-bar {
      position: absolute;
      top: 74px;
      left: 14px;
      display: flex;
      flex-direction: column;
      gap: 7px;
      z-index: 88;
    }

    .light-chip {
      background: rgba(11, 24, 18, 0.82);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(212, 168, 83, 0.28);
      color: rgba(255, 255, 255, 0.88);
      padding: 7px 11px;
      border-radius: 12px;
      font-size: 11px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 5px;
      box-shadow: 0 4px 10px rgba(0, 0, 0, 0.28);
      transition: all 0.18s ease;
    }

    .light-chip.active {
      background: rgba(212, 168, 83, 0.95);
      color: #0b1812;
      border-color: #fff;
      transform: translateX(3px);
    }

    /* ── Quick Hotspot Selector Pills (Above AR Button) ── */
    .hotspot-bar {
      position: absolute;
      bottom: 184px;
      left: 12px;
      right: 12px;
      display: flex;
      gap: 7px;
      overflow-x: auto;
      padding: 4px 4px;
      z-index: 92;
      scrollbar-width: none;
      justify-content: center;
    }
    .hotspot-bar::-webkit-scrollbar {
      display: none;
    }

    .spot-chip {
      background: rgba(11, 24, 18, 0.86);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(212, 168, 83, 0.38);
      color: #fff;
      padding: 6px 11px;
      border-radius: 16px;
      font-size: 11px;
      font-weight: 700;
      white-space: nowrap;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 5px;
      transition: all 0.2s ease;
    }

    .spot-chip span.num {
      background: var(--accent);
      color: #0b1812;
      width: 17px;
      height: 17px;
      border-radius: 50%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 10px;
      font-weight: 800;
    }

    .spot-chip.active {
      background: #34D399;
      color: #052e16;
      border-color: #fff;
      transform: translateY(-2px);
    }

    .spot-chip.active span.num {
      background: #052e16;
      color: #34D399;
    }

    /* ── Big AR Launch Button ── */
    #ar-button {
      background: linear-gradient(135deg, #D4A853 0%, #b88d38 100%);
      color: #0b1812;
      font-weight: 800;
      font-size: 14.5px;
      border-radius: 28px;
      border: 1px solid rgba(255, 255, 255, 0.35);
      padding: 13px 24px;
      position: absolute;
      bottom: 128px;
      left: 50%;
      transform: translateX(-50%);
      white-space: nowrap;
      display: flex;
      align-items: center;
      gap: 9px;
      box-shadow: 0 8px 24px rgba(212, 168, 83, 0.45), 0 2px 8px rgba(0, 0, 0, 0.3);
      cursor: pointer;
      z-index: 100;
      transition: transform 0.15s ease, box-shadow 0.15s ease;
    }

    #ar-button:active {
      transform: translateX(-50%) scale(0.95);
    }

    /* ── Dedicated Loading Screen for 3D Assets ── */
    #loading-overlay {
      position: absolute;
      inset: 0;
      background: radial-gradient(circle at 50% 45%, #163829 0%, #07130d 100%);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      z-index: 120;
      transition: opacity 0.5s ease, visibility 0.5s ease;
      padding: 24px;
      text-align: center;
    }

    #loading-overlay.hidden {
      opacity: 0;
      visibility: hidden;
      pointer-events: none;
    }

    .loading-spinner {
      width: 56px;
      height: 56px;
      border: 4px solid rgba(212, 168, 83, 0.2);
      border-top-color: var(--accent);
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin-bottom: 20px;
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    .loading-title {
      font-size: 17px;
      font-weight: 700;
      color: var(--accent);
      margin-bottom: 8px;
    }

    .loading-status {
      font-size: 13px;
      color: var(--text-muted);
      margin-bottom: 16px;
    }

    .progress-track {
      width: 240px;
      height: 8px;
      background: rgba(255, 255, 255, 0.1);
      border-radius: 10px;
      overflow: hidden;
    }

    .progress-fill {
      width: 5%;
      height: 100%;
      background: linear-gradient(90deg, #D4A853, #52b788);
      border-radius: 10px;
      transition: width 0.25s ease;
    }

    /* ── Bottom Interactive Inspector / Audio Tour Card ── */
    .info-card {
      position: absolute;
      bottom: 14px;
      left: 14px;
      right: 14px;
      background: rgba(18, 46, 34, 0.94);
      backdrop-filter: blur(16px);
      border: 1px solid rgba(212, 168, 83, 0.45);
      border-radius: 20px;
      padding: 13px 16px;
      color: #fff;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.55);
      z-index: 95;
      cursor: pointer;
      transition: all 0.25s ease;
    }

    .info-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
    }

    .info-badge-group {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: wrap;
    }

    .info-badge {
      display: inline-block;
      background: rgba(212, 168, 83, 0.22);
      border: 1px solid rgba(212, 168, 83, 0.55);
      color: var(--accent);
      font-size: 10px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .info-spot-title {
      font-size: 13.5px;
      font-weight: 800;
      color: #ffffff;
      margin-top: 5px;
    }

    .info-desc {
      font-size: 12px;
      line-height: 1.42;
      color: var(--text-muted);
      margin-top: 4px;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .info-desc.expanded {
      -webkit-line-clamp: unset;
      max-height: 150px;
      overflow-y: auto;
    }

    .tour-progress-bar {
      height: 3px;
      background: rgba(255, 255, 255, 0.14);
      border-radius: 4px;
      margin-top: 8px;
      overflow: hidden;
      display: none;
    }
    .tour-progress-bar.active {
      display: block;
    }
    .tour-progress-fill {
      height: 100%;
      width: 0%;
      background: #34D399;
      transition: width 0.3s linear;
    }

    /* ── No Model State ── */
    .no-model-box {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      text-align: center;
      padding: 30px 20px;
      background: rgba(27, 67, 50, 0.9);
      backdrop-filter: blur(14px);
      border: 1px solid rgba(212, 168, 83, 0.4);
      border-radius: 20px;
      max-width: 85%;
      z-index: 50;
    }
  </style>
</head>
<body class="mode-day">

  <div id="viewer-container">
    <div id="era-overlay"></div>
    <div id="era-watermark">
      <span>📜 {{ $landmark->era ?: 'Spanish Colonial Era' }} Archival View</span>
    </div>

    <!-- Top Nav Header -->
    <div class="top-bar">
      <button class="top-btn" onclick="window.history.back()" title="Back">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M19 12H5M12 19l-7-7 7-7"/>
        </svg>
      </button>

      <div class="title-pill">
        <h1>{{ $landmark->name }}</h1>
        <span>{{ $landmark->municipality->name ?? 'Pangasinan' }}{{ $landmark->era ? ' • ' . $landmark->era : '' }}</span>
      </div>

      <button class="top-btn" onclick="toggleFullscreen()" title="Fullscreen">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"/>
        </svg>
      </button>
    </div>

    @if($modelUrl)
      <!-- Left Atmosphere & Era Lighting Switcher -->
      <div class="lighting-bar">
        <button class="light-chip active" id="light-day" onclick="setLighting('day')">
          ☀️ Day
        </button>
        <button class="light-chip" id="light-golden" onclick="setLighting('golden')">
          🌅 Golden
        </button>
        <button class="light-chip" id="light-night" onclick="setLighting('night')">
          🕯️ Night
        </button>
        <button class="light-chip" id="light-era" onclick="setLighting('era')">
          📜 Era
        </button>
      </div>

      <!-- Right Interactive Controls Stack -->
      <div class="controls-stack">
        <button id="tour-btn" class="control-btn" onclick="toggleGuidedTour()" title="Guided Audio & Camera Tour">
          <span id="tour-icon">🎧</span>
          <span id="tour-label">Tour</span>
        </button>
        <button id="pins-btn" class="control-btn active" onclick="toggleHotspots()" title="Toggle 3D Hotspots">
          📍 Pins
        </button>
        <button id="rotate-btn" class="control-btn active" onclick="toggleAutoRotate()" title="Toggle Auto-Rotate">
          ↻ Spin
        </button>
        <button class="control-btn" onclick="resetCamera()" title="Reset 3D View">
          ⟲ Reset
        </button>
      </div>

      <!-- Loading Screen while GLB downloads -->
      <div id="loading-overlay">
        <div class="loading-spinner"></div>
        <div class="loading-title">Loading Interactive 3D Landmark</div>
        <div class="loading-status" id="loading-status">Downloading 3D model... (0%)</div>
        <div class="progress-track">
          <div class="progress-fill" id="progress-fill"></div>
        </div>
      </div>

      <!-- Google 3D & Markerless Surface AR Model Viewer with Interactive Hotspots -->
      <model-viewer
        id="landmark-model"
        src="{{ $modelUrl }}"
        alt="{{ $landmark->name }} 3D Model"
        ar
        ar-modes="webxr scene-viewer quick-look"
        ar-scale="auto"
        camera-controls
        touch-action="pan-y"
        interaction-prompt="none"
        auto-rotate
        rotation-per-second="20deg"
        shadow-intensity="1.25"
        shadow-softness="0.65"
        exposure="1.05"
        bounds="tight"
        camera-orbit="0deg 75deg auto"
        min-camera-orbit="auto auto 5%"
        max-camera-orbit="auto auto 300%">

        <!-- 4 Dynamic 3D Surface Hotspots (positioned automatically using bounding box on load) -->
        <button slot="hotspot-1" class="hotspot-pin" id="pin-0" data-position="0 0 0" data-normal="0 0 1" onclick="focusHotspot(0, event)">
          1
          <span class="hotspot-tag" id="tag-0">Main Facade</span>
        </button>

        <button slot="hotspot-2" class="hotspot-pin" id="pin-1" data-position="0 0 0" data-normal="0 1 0" onclick="focusHotspot(1, event)">
          2
          <span class="hotspot-tag" id="tag-1">Upper Structure</span>
        </button>

        <button slot="hotspot-3" class="hotspot-pin" id="pin-2" data-position="0 0 0" data-normal="-1 0 0" onclick="focusHotspot(2, event)">
          3
          <span class="hotspot-tag" id="tag-2">Architecture</span>
        </button>

        <button slot="hotspot-4" class="hotspot-pin" id="pin-3" data-position="0 0 0" data-normal="0 0 -1" onclick="focusHotspot(3, event)">
          4
          <span class="hotspot-tag" id="tag-3">Heritage Legacy</span>
        </button>

        <!-- AR Launch Button -->
        <button slot="ar-button" id="ar-button">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/>
            <path d="m3.3 7 8.7 5 8.7-5"/>
            <path d="M12 22V12"/>
          </svg>
          Place in Your Space (AR)
        </button>

      </model-viewer>

      <!-- Quick Hotspot Selector Bar -->
      <div class="hotspot-bar" id="hotspot-bar">
        <button class="spot-chip" id="chip-0" onclick="focusHotspot(0, event)">
          <span class="num">1</span> <span id="chip-label-0">Facade</span>
        </button>
        <button class="spot-chip" id="chip-1" onclick="focusHotspot(1, event)">
          <span class="num">2</span> <span id="chip-label-1">Crown</span>
        </button>
        <button class="spot-chip" id="chip-2" onclick="focusHotspot(2, event)">
          <span class="num">3</span> <span id="chip-label-2">Masonry</span>
        </button>
        <button class="spot-chip" id="chip-3" onclick="focusHotspot(3, event)">
          <span class="num">4</span> <span id="chip-label-3">History</span>
        </button>
      </div>
    @else
      <div class="no-model-box">
        <h3 style="color: var(--accent); margin-bottom: 8px;">3D Model Coming Soon</h3>
        <p style="font-size: 13px; color: var(--text-muted);">A 3D recreation for <strong>{{ $landmark->name }}</strong> is being prepared.</p>
      </div>
    @endif

    <!-- Bottom Interactive Inspector Card -->
    <div class="info-card" onclick="toggleDesc(event)">
      <div class="info-header">
        <div class="info-badge-group">
          <span class="info-badge" id="card-badge">{{ $landmark->category }}</span>
          @if($landmark->era)
            <span class="info-badge" style="background: rgba(52, 211, 153, 0.18); border-color: rgba(52, 211, 153, 0.5); color: #6EE7B7;">
              {{ $landmark->era }}
            </span>
          @endif
        </div>
        <span style="font-size: 11px; color: var(--accent); font-weight: 700;" id="card-action-hint">Tap pin ①–④ to inspect</span>
      </div>
      <div class="info-spot-title" id="info-title">{{ $landmark->name }}</div>
      <p class="info-desc" id="info-desc">
        {{ $landmark->description ?: $landmark->short_description }}
      </p>
      <div class="tour-progress-bar" id="tour-progress-bar">
        <div class="tour-progress-fill" id="tour-progress-fill"></div>
      </div>
    </div>
  </div>

  <script>
    const viewer = document.querySelector('#landmark-model');
    const loadingOverlay = document.querySelector('#loading-overlay');
    const progressFill = document.querySelector('#progress-fill');
    const loadingStatus = document.querySelector('#loading-status');

    const landmarkData = {
      name: @json($landmark->name),
      category: @json(strtolower($landmark->category ?? 'historical')),
      era: @json($landmark->era ?? 'Spanish Colonial Era'),
      municipality: @json($landmark->municipality->name ?? 'Pangasinan'),
      address: @json($landmark->address ?? ''),
      shortDesc: @json($landmark->short_description ?? ''),
      fullDesc: @json($landmark->description ?: $landmark->short_description),
    };

    // Build 4 context-aware architectural & historical hotspots for this landmark
    const hotspots = buildHotspotsForLandmark(landmarkData);
    let hotspotsVisible = true;
    let activeSpotIndex = -1;
    let tourTimer = null;
    let tourActive = false;

    function buildHotspotsForLandmark(lm) {
      const isChurch = lm.category === 'church';
      const isRail = lm.name.toLowerCase().includes('pnr') || lm.name.toLowerCase().includes('station') || lm.name.toLowerCase().includes('franklin');

      return [
        {
          shortLabel: isChurch ? 'Portal & Facade' : (isRail ? 'Main Frontage' : 'Primary Facade'),
          title: `① ${isChurch ? 'Main Church Portal & Facade' : 'Historic Front Elevation'}`,
          badge: 'Point 1 • Front View',
          body: lm.shortDesc || `The primary entrance and historic facade of ${lm.name} in ${lm.municipality}, welcoming visitors and pilgrims since the ${lm.era}.`,
          orbit: '0deg 78deg 62%',
          offset: { x: 0.0, y: -0.10, z: 0.44 }
        },
        {
          shortLabel: isChurch ? 'Belfry & Crown' : (isRail ? 'Roof & Gable' : 'Upper Crown'),
          title: `② ${isChurch ? 'Bell Tower & Upper Pediment' : 'Upper Structural Crown'}`,
          badge: 'Point 2 • Upper Detail',
          body: isChurch
            ? `Rising above ${lm.municipality}, the upper pediment and belfry showcase ${lm.era} ecclesiastical proportions designed to be visible across the town plaza.`
            : `The upper roofline and structural crown of ${lm.name} reflect period engineering from the ${lm.era} in ${lm.municipality}.`,
          orbit: '34deg 58deg 58%',
          offset: { x: 0.16, y: 0.34, z: 0.14 }
        },
        {
          shortLabel: isChurch ? 'Colonial Masonry' : 'Structural Wing',
          title: `③ ${isChurch ? 'Heritage Brickwork & Buttresses' : 'Period Masonry & Craftsmanship'}`,
          badge: 'Point 3 • Architecture',
          body: `Built to withstand Pangasinan's coastal climate and seismic history, the side walls and structural supports preserve authentic ${lm.era} construction techniques.`,
          orbit: '-58deg 72deg 64%',
          offset: { x: -0.34, y: 0.04, z: 0.05 }
        },
        {
          shortLabel: 'Heritage Legacy',
          title: `④ Historical Significance in ${lm.municipality}`,
          badge: 'Point 4 • Heritage Story',
          body: lm.fullDesc,
          orbit: '135deg 68deg 70%',
          offset: { x: 0.24, y: -0.04, z: -0.28 }
        }
      ];
    }

    // Populate chip and pin labels immediately
    hotspots.forEach((h, idx) => {
      const tagEl = document.getElementById(`tag-${idx}`);
      const chipLabelEl = document.getElementById(`chip-${idx}`);
      if (tagEl) tagEl.innerText = h.shortLabel;
      if (chipLabelEl) {
        chipLabelEl.innerHTML = `<span class="num">${idx + 1}</span> <span>${h.shortLabel}</span>`;
      }
    });

    if (viewer) {
      let loadHandled = false;

      function revealModel() {
        if (loadHandled) return;
        loadHandled = true;
        positionHotspotsFromBoundingBox();

        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            if (loadingOverlay) loadingOverlay.classList.add('hidden');
          });
        });
      }

      // Compute exact 3D surface coordinates from the loaded GLB's bounding box
      function positionHotspotsFromBoundingBox() {
        try {
          const center = viewer.getBoundingBoxCenter();
          const dim = viewer.getDimensions();
          hotspots.forEach((h, idx) => {
            const px = (center.x + dim.x * h.offset.x).toFixed(3);
            const py = (center.y + dim.y * h.offset.y).toFixed(3);
            const pz = (center.z + dim.z * h.offset.z).toFixed(3);
            const posStr = `${px}m ${py}m ${pz}m`;
            h.worldPos = `${px}m ${py}m ${pz}m`;
            viewer.updateHotspot({
              name: `hotspot-${idx + 1}`,
              position: posStr
            });
          });
        } catch (e) {
          console.warn('Bounding box hotspot placement fallback:', e);
        }
      }

      viewer.addEventListener('progress', (event) => {
        const percent = Math.round(event.detail.totalProgress * 100);
        if (progressFill) progressFill.style.width = Math.max(percent, 8) + '%';
        if (loadingStatus) loadingStatus.innerText = `Downloading 3D model... (${percent}%)`;
      });

      viewer.addEventListener('load', () => {
        revealModel();
      });

      viewer.addEventListener('model-visibility', (e) => {
        if (e.detail.visible) revealModel();
      });

      viewer.addEventListener('error', () => {
        loadHandled = true;
        if (loadingStatus) {
          loadingStatus.innerText = '⚠️ Failed to load 3D model.';
          loadingStatus.style.color = '#ff6b6b';
        }
      });
    }

    // Swoop 3D camera to a specific hotspot and show its story card
    function focusHotspot(index, event) {
      if (event) event.stopPropagation();
      if (!viewer || index < 0 || index >= hotspots.length) return;

      activeSpotIndex = index;
      const spot = hotspots[index];

      // Highlight selected pin and chip
      for (let i = 0; i < hotspots.length; i++) {
        const pin = document.getElementById(`pin-${i}`);
        const chip = document.getElementById(`chip-${i}`);
        if (pin) pin.classList.toggle('active', i === index);
        if (chip) chip.classList.toggle('active', i === index);
      }

      // Pause auto-rotate so user can inspect the zoomed feature
      viewer.autoRotate = false;
      const rotBtn = document.getElementById('rotate-btn');
      if (rotBtn) rotBtn.classList.remove('active');

      // Smoothly target and orbit the 3D camera onto the hotspot
      if (spot.worldPos) {
        viewer.cameraTarget = spot.worldPos;
      }
      viewer.cameraOrbit = spot.orbit;

      // Update bottom inspector card
      document.getElementById('card-badge').innerText = spot.badge;
      document.getElementById('info-title').innerText = spot.title;
      const descEl = document.getElementById('info-desc');
      descEl.innerText = spot.body;
      descEl.classList.add('expanded');
      document.getElementById('card-action-hint').innerText = '🔊 Narrating • Tap to collapse';

      speakText(`${spot.title.replace(/^[①②③④]\s*/, '')}. ${spot.body}`);
    }

    // Narrate text using Web Speech API (if supported by device WebView)
    function speakText(text) {
      try {
        if ('speechSynthesis' in window) {
          window.speechSynthesis.cancel();
          const utter = new SpeechSynthesisUtterance(text);
          utter.rate = 0.98;
          utter.pitch = 1.0;
          window.speechSynthesis.speak(utter);
        }
      } catch (_) {}
    }

    // Toggle Automated Guided Tour (cycles through all 4 hotspots with camera swoops + voice)
    function toggleGuidedTour() {
      tourActive = !tourActive;
      const btn = document.getElementById('tour-btn');
      const label = document.getElementById('tour-label');
      const progBar = document.getElementById('tour-progress-bar');
      const progFill = document.getElementById('tour-progress-fill');

      if (tourActive) {
        btn.classList.add('tour-active');
        label.innerText = 'Stop';
        progBar.classList.add('active');

        let step = 0;
        const stepDurationMs = 7000;
        focusHotspot(step);
        progFill.style.width = '25%';

        tourTimer = setInterval(() => {
          step = (step + 1) % hotspots.length;
          focusHotspot(step);
          progFill.style.width = `${((step + 1) / hotspots.length) * 100}%`;
        }, stepDurationMs);
      } else {
        stopGuidedTour();
      }
    }

    function stopGuidedTour() {
      tourActive = false;
      if (tourTimer) {
        clearInterval(tourTimer);
        tourTimer = null;
      }
      try {
        if ('speechSynthesis' in window) window.speechSynthesis.cancel();
      } catch (_) {}
      const btn = document.getElementById('tour-btn');
      const label = document.getElementById('tour-label');
      const progBar = document.getElementById('tour-progress-bar');
      if (btn) btn.classList.remove('tour-active');
      if (label) label.innerText = 'Tour';
      if (progBar) progBar.classList.remove('active');
    }

    // Show / Hide 3D surface hotspot pins
    function toggleHotspots() {
      hotspotsVisible = !hotspotsVisible;
      const btn = document.getElementById('pins-btn');
      if (btn) btn.classList.toggle('active', hotspotsVisible);
      for (let i = 0; i < hotspots.length; i++) {
        const pin = document.getElementById(`pin-${i}`);
        if (pin) pin.classList.toggle('hidden-pin', !hotspotsVisible);
      }
    }

    // Switch Atmosphere & Era Lighting
    function setLighting(mode) {
      document.body.className = `mode-${mode}`;
      ['day', 'golden', 'night', 'era'].forEach((m) => {
        const chip = document.getElementById(`light-${m}`);
        if (chip) chip.classList.toggle('active', m === mode);
      });

      if (!viewer) return;
      if (mode === 'day') {
        viewer.exposure = 1.05;
        viewer.shadowIntensity = 1.25;
      } else if (mode === 'golden') {
        viewer.exposure = 0.92;
        viewer.shadowIntensity = 1.85;
      } else if (mode === 'night') {
        viewer.exposure = 0.55;
        viewer.shadowIntensity = 2.0;
      } else if (mode === 'era') {
        viewer.exposure = 0.95;
        viewer.shadowIntensity = 1.45;
      }
    }

    function toggleAutoRotate() {
      if (!viewer) return;
      stopGuidedTour();
      const btn = document.getElementById('rotate-btn');
      viewer.autoRotate = !viewer.autoRotate;
      btn.classList.toggle('active', viewer.autoRotate);
    }

    function resetCamera() {
      if (!viewer) return;
      stopGuidedTour();
      activeSpotIndex = -1;
      for (let i = 0; i < hotspots.length; i++) {
        const pin = document.getElementById(`pin-${i}`);
        const chip = document.getElementById(`chip-${i}`);
        if (pin) pin.classList.remove('active');
        if (chip) chip.classList.remove('active');
      }
      viewer.cameraTarget = 'auto auto auto';
      viewer.cameraOrbit = '0deg 75deg auto';
      viewer.autoRotate = true;
      document.getElementById('rotate-btn')?.classList.add('active');
      document.getElementById('card-badge').innerText = landmarkData.category;
      document.getElementById('info-title').innerText = landmarkData.name;
      const descEl = document.getElementById('info-desc');
      descEl.innerText = landmarkData.fullDesc;
      descEl.classList.remove('expanded');
      document.getElementById('card-action-hint').innerText = 'Tap pin ①–④ to inspect';
    }

    function toggleDesc(e) {
      const desc = document.getElementById('info-desc');
      if (desc) desc.classList.toggle('expanded');
    }

    function toggleFullscreen() {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
      } else {
        document.exitFullscreen().catch(() => {});
      }
    }
  </script>
</body>
</html>
