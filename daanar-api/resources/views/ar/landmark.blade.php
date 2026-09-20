<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <title>AR — {{ $landmark->name }}</title>

  {{-- A-Frame core --}}
  <script src="https://aframe.io/releases/1.5.0/aframe.min.js"></script>

  {{-- AR.js with NFT + marker support --}}
  @if($demoMode)
    {{-- Marker-based AR.js for demo mode (HIRO marker) --}}
    <script src="https://raw.githack.com/AR-js-org/AR.js/master/aframe/build/aframe-ar.js"></script>
  @else
    {{-- NFT-based AR.js for image target tracking --}}
    <script src="https://raw.githack.com/AR-js-org/AR.js/master/aframe/build/aframe-ar-nft.js"></script>
  @endif

  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { overflow: hidden; font-family: 'Segoe UI', sans-serif; }

    /* Info panel — floats at the bottom */
    #info-panel {
      position: fixed;
      bottom: 24px;
      left: 16px;
      right: 16px;
      background: rgba(27, 67, 50, 0.88);
      backdrop-filter: blur(12px);
      border-radius: 18px;
      padding: 18px 20px;
      color: #fff;
      z-index: 9999;
      border: 1px solid rgba(212, 168, 83, 0.4);
      transition: transform 0.3s ease;
    }
    #info-panel h2 {
      font-size: 17px;
      font-weight: 700;
      color: #D4A853;
      margin-bottom: 6px;
      letter-spacing: 0.3px;
    }
    #info-panel p {
      font-size: 13px;
      color: rgba(255,255,255,0.85);
      line-height: 1.5;
      max-height: 60px;
      overflow: hidden;
    }
    #info-panel .badge {
      display: inline-block;
      background: rgba(212,168,83,0.2);
      border: 1px solid rgba(212,168,83,0.5);
      color: #D4A853;
      font-size: 11px;
      font-weight: 600;
      padding: 3px 10px;
      border-radius: 20px;
      margin-bottom: 8px;
      text-transform: capitalize;
    }

    /* Mode indicator */
    #mode-badge {
      position: fixed;
      top: 16px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0,0,0,0.65);
      color: #fff;
      font-size: 12px;
      padding: 6px 16px;
      border-radius: 20px;
      z-index: 9999;
      backdrop-filter: blur(8px);
    }

    /* Marker hint */
    #marker-hint {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      text-align: center;
      color: rgba(255,255,255,0.85);
      z-index: 9998;
      pointer-events: none;
    }
    #marker-hint .frame {
      width: 200px;
      height: 200px;
      border: 3px solid rgba(212,168,83,0.7);
      border-radius: 16px;
      margin: 0 auto 12px;
      position: relative;
      animation: pulse 2s ease-in-out infinite;
    }
    #marker-hint .frame::before,
    #marker-hint .frame::after {
      content: '';
      position: absolute;
      width: 24px;
      height: 24px;
      border-color: #D4A853;
      border-style: solid;
    }
    #marker-hint .frame::before {
      top: -3px; left: -3px;
      border-width: 3px 0 0 3px;
      border-radius: 4px 0 0 0;
    }
    #marker-hint .frame::after {
      bottom: -3px; right: -3px;
      border-width: 0 3px 3px 0;
      border-radius: 0 0 4px 0;
    }
    #marker-hint p {
      font-size: 14px;
      font-weight: 500;
      text-shadow: 0 1px 4px rgba(0,0,0,0.6);
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }

    /* Hide A-Frame UI chrome */
    .a-enter-vr, .a-loader-title { display: none !important; }
  </style>
</head>
<body>

  {{-- ── Mode badge ──────────────────────────────────────────────────── --}}
  <div id="mode-badge">
    @if($demoMode)
      🔲 Demo Mode — Point camera at HIRO marker
    @else
      📷 AR Mode — Point camera at the heritage marker
    @endif
  </div>

  {{-- ── Marker targeting hint ──────────────────────────────────────── --}}
  <div id="marker-hint">
    <div class="frame"></div>
    <p>
      @if($demoMode)
        Print or display the HIRO marker<br>and point your camera at it
      @else
        Point your camera at the<br>landmark AR marker
      @endif
    </p>
  </div>

  {{-- ══════════════════════════════════════════════════════════════════
       A-Frame Scene
  ══════════════════════════════════════════════════════════════════ --}}
  @if($demoMode)
  {{-- DEMO MODE: HIRO marker tracking --}}
  <a-scene
    embedded
    arjs="sourceType: webcam; debugUIEnabled: false; detectionMode: mono_and_matrix; matrixCodeType: 3x3;"
    renderer="logarithmicDepthBuffer: true; antialias: true;"
    vr-mode-ui="enabled: false"
    loading-screen="enabled: false">

    <a-marker preset="hiro" id="ar-marker">
      {{-- 3D model if available, otherwise animated landmark stand-in --}}
      @if($modelUrl)
        <a-entity
          gltf-model="{{ $modelUrl }}"
          scale="0.5 0.5 0.5"
          position="0 0.5 0"
          animation="property: rotation; to: 0 360 0; loop: true; dur: 8000; easing: linear">
        </a-entity>
      @else
        {{-- Default: stacked heritage building stand-in --}}
        <a-entity position="0 0.5 0"
          animation="property: rotation; to: 0 360 0; loop: true; dur: 8000; easing: linear">
          <a-box color="#1B4332" depth="0.8" height="0.1" width="0.8" position="0 0 0"></a-box>
          <a-box color="#2D6A4F" depth="0.55" height="0.3" width="0.55" position="0 0.2 0"></a-box>
          <a-box color="#1B4332" depth="0.35" height="0.25" width="0.35" position="0 0.475 0"></a-box>
          <a-cone color="#D4A853" radius-bottom="0.25" radius-top="0.02" height="0.3" position="0 0.775 0"></a-cone>
        </a-entity>
      @endif

      {{-- Landmark name text above model --}}
      <a-text
        value="{{ $landmark->name }}"
        align="center"
        color="#D4A853"
        position="0 1.5 0"
        scale="0.6 0.6 0.6"
        font="sourceserifpro">
      </a-text>
    </a-marker>

    <a-entity camera></a-entity>
  </a-scene>

  @else
  {{-- NFT MODE: Image target tracking --}}
  <a-scene
    embedded
    arjs="sourceType: webcam; debugUIEnabled: false;"
    renderer="logarithmicDepthBuffer: true; antialias: true;"
    vr-mode-ui="enabled: false"
    loading-screen="enabled: false">

    <a-nft
      type="nft"
      url="{{ $nftBasePath }}"
      smooth="true"
      smoothCount="10"
      smoothTolerance="0.01"
      smoothThreshold="5">

      @if($modelUrl)
        <a-entity
          gltf-model="{{ $modelUrl }}"
          scale="0.5 0.5 0.5"
          position="0 0 0"
          rotation="270 0 0">
        </a-entity>
      @else
        <a-entity position="0 0 0" rotation="270 0 0">
          <a-box color="#1B4332" depth="0.8" height="0.1" width="0.8"></a-box>
          <a-box color="#2D6A4F" depth="0.55" height="0.3" width="0.55" position="0 0.2 0"></a-box>
          <a-cone color="#D4A853" radius-bottom="0.2" radius-top="0.02" height="0.25" position="0 0.425 0"></a-cone>
        </a-entity>
      @endif
    </a-nft>

    <a-entity camera></a-entity>
  </a-scene>
  @endif

  {{-- ── Info panel ──────────────────────────────────────────────────── --}}
  <div id="info-panel">
    <span class="badge">{{ $landmark->category }}</span>
    <h2>{{ $landmark->name }}</h2>
    <p>{{ $landmark->short_description ?: Str::limit($landmark->description, 120) }}</p>
  </div>

  <script>
    // Hide marker hint once a marker/NFT is found
    const scene = document.querySelector('a-scene');
    const hint  = document.getElementById('marker-hint');

    @if($demoMode)
    const marker = document.querySelector('a-marker');
    if (marker) {
      marker.addEventListener('markerFound', () => {
        hint.style.display = 'none';
      });
      marker.addEventListener('markerLost', () => {
        hint.style.display = 'block';
      });
    }
    @else
    const nft = document.querySelector('a-nft');
    if (nft) {
      nft.addEventListener('markerFound', () => {
        hint.style.display = 'none';
      });
      nft.addEventListener('markerLost', () => {
        hint.style.display = 'block';
      });
    }
    @endif
  </script>
</body>
</html>
