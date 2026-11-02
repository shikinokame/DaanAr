<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="theme-color" content="#1B4332">
  <title>{{ $landmark->name }} 3D & AR Experience</title>

  <!-- Google Model Viewer (Industry standard 3D & Markerless AR) -->
  <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js"></script>

  <style>
    :root {
      --primary: #1B4332;
      --accent: #D4A853;
      --accent-hover: #e0b865;
      --bg-dark: #0b1812;
      --text: #ffffff;
      --text-muted: rgba(255, 255, 255, 0.75);
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
    }

    /* ── Top Bar ── */
    .top-bar {
      position: absolute;
      top: env(safe-area-inset-top, 16px);
      left: 16px;
      right: 16px;
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
      max-width: 65%;
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

    /* ── Floating Side Controls ── */
    .controls-stack {
      position: absolute;
      top: 80px;
      right: 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      z-index: 90;
    }

    .control-btn {
      background: rgba(11, 24, 18, 0.85);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(212, 168, 83, 0.3);
      color: #fff;
      width: 40px;
      height: 40px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      transition: transform 0.15s ease, background 0.15s ease;
    }

    .control-btn.active {
      background: var(--accent);
      color: #0b1812;
      border-color: var(--accent);
    }

    .control-btn:active {
      transform: scale(0.92);
    }

    /* ── Touch Interaction Guidance ── */
    .interaction-hint {
      position: absolute;
      top: 22%;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(11, 24, 18, 0.85);
      backdrop-filter: blur(10px);
      padding: 8px 16px;
      border-radius: 20px;
      font-size: 12px;
      color: var(--accent);
      font-weight: 600;
      pointer-events: none;
      display: flex;
      align-items: center;
      gap: 8px;
      border: 1px solid rgba(212, 168, 83, 0.3);
      z-index: 60;
      transition: opacity 0.5s ease;
    }

    /* ── Big AR Launch Button ── */
    #ar-button {
      background: linear-gradient(135deg, #D4A853 0%, #b88d38 100%);
      color: #0b1812;
      font-weight: 700;
      font-size: 15px;
      border-radius: 28px;
      border: none;
      padding: 14px 26px;
      position: absolute;
      bottom: 110px;
      left: 50%;
      transform: translateX(-50%);
      white-space: nowrap;
      display: flex;
      align-items: center;
      gap: 10px;
      box-shadow: 0 8px 24px rgba(212, 168, 83, 0.45), 0 2px 8px rgba(0, 0, 0, 0.3);
      cursor: pointer;
      z-index: 100;
      transition: transform 0.15s ease, box-shadow 0.15s ease;
    }

    #ar-button:active {
      transform: translateX(-50%) scale(0.95);
      box-shadow: 0 4px 12px rgba(212, 168, 83, 0.3);
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
      z-index: 70;
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
      box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.4);
    }

    .progress-fill {
      width: 5%;
      height: 100%;
      background: linear-gradient(90deg, #D4A853, #52b788);
      border-radius: 10px;
      transition: width 0.25s ease;
    }

    /* ── Bottom Information Card ── */
    .info-card {
      position: absolute;
      bottom: 16px;
      left: 16px;
      right: 16px;
      background: rgba(27, 67, 50, 0.92);
      backdrop-filter: blur(16px);
      border: 1px solid rgba(212, 168, 83, 0.35);
      border-radius: 20px;
      padding: 14px 18px;
      color: #fff;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
      z-index: 90;
      cursor: pointer;
      transition: all 0.2s ease;
    }

    .info-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    .info-badge {
      display: inline-block;
      background: rgba(212, 168, 83, 0.2);
      border: 1px solid rgba(212, 168, 83, 0.5);
      color: var(--accent);
      font-size: 10px;
      font-weight: 700;
      padding: 2px 8px;
      border-radius: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .info-desc {
      font-size: 12px;
      line-height: 1.4;
      color: var(--text-muted);
      margin-top: 6px;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .info-desc.expanded {
      -webkit-line-clamp: unset;
      max-height: 160px;
      overflow-y: auto;
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

    .no-model-box svg {
      width: 48px;
      height: 48px;
      stroke: var(--accent);
      margin-bottom: 12px;
    }

    .no-model-box h3 {
      font-size: 16px;
      color: var(--accent);
      margin-bottom: 6px;
    }

    .no-model-box p {
      font-size: 12px;
      color: var(--text-muted);
      line-height: 1.5;
    }
  </style>
</head>
<body>

  <div id="viewer-container">
    <!-- Top Nav Header -->
    <div class="top-bar">
      <button class="top-btn" onclick="window.history.back()" title="Back">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M19 12H5M12 19l-7-7 7-7"/>
        </svg>
      </button>

      <div class="title-pill">
        <h1>{{ $landmark->name }}</h1>
        <span>{{ $landmark->municipality->name ?? 'Pangasinan' }}</span>
      </div>

      <button class="top-btn" onclick="toggleFullscreen()" title="Fullscreen">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"/>
        </svg>
      </button>
    </div>

    <!-- Quick Floating Controls -->
    <div class="controls-stack">
      <button id="rotate-btn" class="control-btn active" onclick="toggleAutoRotate()" title="Toggle Rotation">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/>
        </svg>
      </button>
      <button class="control-btn" onclick="resetCamera()" title="Reset View">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/>
          <path d="m10 15 5-3-5-3v6Z"/>
        </svg>
      </button>
    </div>

    <!-- Center Interaction Hint -->
    <div class="interaction-hint" id="hint-pill">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Zm0 18a8 8 0 1 1 8-8 8 8 0 0 1-8 8Z"/>
        <path d="M12 6v6l4 2"/>
      </svg>
      <span>Drag to rotate • Pinch to zoom</span>
    </div>

    @if($modelUrl)
      <!-- Loading Screen while GLB downloads -->
      <div id="loading-overlay">
        <div class="loading-spinner"></div>
        <div class="loading-title">Loading 3D Landmark</div>
        <div class="loading-status" id="loading-status">Downloading 3D model... (0%)</div>
        <div class="progress-track">
          <div class="progress-fill" id="progress-fill"></div>
        </div>
      </div>

      <!-- Google 3D & Markerless Surface AR Model Viewer -->
      <model-viewer
        id="landmark-model"
        src="{{ $modelUrl }}"
        alt="{{ $landmark->name }} 3D Model"
        ar
        ar-modes="scene-viewer webxr quick-look"
        ar-scale="auto"
        camera-controls
        touch-action="pan-y"
        interaction-prompt="none"
        auto-rotate
        rotation-per-second="25deg"
        shadow-intensity="1.2"
        shadow-softness="0.7"
        exposure="1.0"
        bounds="tight"
        camera-orbit="0deg 75deg auto"
        min-camera-orbit="auto auto 5%"
        max-camera-orbit="auto auto 300%">

        <!-- AR Button -->
        <button slot="ar-button" id="ar-button">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/>
            <path d="m3.3 7 8.7 5 8.7-5"/>
            <path d="M12 22V12"/>
          </svg>
          View in your Space (AR)
        </button>

      </model-viewer>
    @else
      <div class="no-model-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/>
          <path d="M3.27 6.96 12 12.01l8.73-5.05M12 22.08V12"/>
        </svg>
        <h3>3D Model Coming Soon</h3>
        <p>A 3D recreation for <strong>{{ $landmark->name }}</strong> is currently being prepared.</p>
      </div>
    @endif

    <!-- Bottom Landmark Card -->
    <div class="info-card" onclick="toggleDesc(event)">
      <div class="info-header">
        <span class="info-badge">{{ $landmark->category }}</span>
        <span style="font-size: 11px; color: var(--accent); font-weight: 600;">Tap for details</span>
      </div>
      <p class="info-desc" id="info-desc">
        {{ $landmark->description ?: $landmark->short_description }}
      </p>
    </div>
  </div>

  <aside id="ar-diagnostics" role="status" hidden style="position:fixed;z-index:10000;left:12px;right:12px;top:12px;max-height:45vh;overflow:auto;background:#10251b;color:#fff;border:1px solid #D4A853;border-radius:12px;padding:16px;box-shadow:0 4px 24px #0009;">
    <button type="button" onclick="document.getElementById('ar-diagnostics').hidden = true" style="float:right;padding:4px 10px;">Close</button>
    <strong>AR details</strong>
    <pre id="ar-diagnostic-text" style="white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.5 monospace;margin-top:12px;user-select:text;"></pre>
  </aside>

  <script>
    const viewer = document.querySelector('#landmark-model');
    const loadingOverlay = document.querySelector('#loading-overlay');
    const progressFill = document.querySelector('#progress-fill');
    const loadingStatus = document.querySelector('#loading-status');
    const hintPill = document.querySelector('#hint-pill');

    function showArDiagnostic(detail) {
      const modelUrl = detail.modelUrl || (viewer && viewer.src) || '(missing)';
      const text = `${detail.status}: ${detail.message}\nModel URL: ${modelUrl}`;
      console[detail.status === 'error' ? 'error' : 'info']('DaanAR AR:', text);
      // Successful handoffs and returning with Back are not errors. Keep the
      // preview clear; technical details are useful only for actual failures.
      if (detail.status !== 'error') return;
      document.getElementById('ar-diagnostic-text').textContent = text;
      document.getElementById('ar-diagnostics').hidden = false;
    }

    // Native download/launch/result diagnostics are forwarded by Flutter.
    window.addEventListener('daanar-ar-diagnostic', event => showArDiagnostic(event.detail));

    if (viewer) {
      let loadHandled = false;

      document.getElementById('ar-button').addEventListener('click', event => {
        try {
          const url = new URL(viewer.src, location.href);
          if (url.protocol !== 'https:' || !/\.glb$/i.test(url.pathname) ||
              url.username || url.password || url.hash ||
              url.hostname === 'localhost' || url.hostname.endsWith('.local')) {
            throw new Error('AR requires a publicly accessible HTTPS .glb URL.');
          }
          showArDiagnostic({status: 'launching', message: 'Opening AR viewer. If it closes, native result details will appear here.', modelUrl: url.href});
        } catch (error) {
          event.preventDefault();
          event.stopImmediatePropagation();
          showArDiagnostic({status: 'error', message: error.message});
        }
      }, true);

      viewer.addEventListener('ar-status', event => {
        if (event.detail.status === 'failed') {
          showArDiagnostic({status: 'error', message: 'AR could not start. Check that Google and Google Play Services for AR are installed and enabled, then try again.'});
        }
      });

      // Helper: hide overlay once WebGL has actually rendered the first frame
      function revealModel() {
        if (loadHandled) return;
        loadHandled = true;

        // Wait for the next two animation frames so WebGL finishes compositing
        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            if (loadingOverlay) loadingOverlay.classList.add('hidden');
            if (hintPill) {
              setTimeout(() => { hintPill.style.opacity = '0'; }, 3500);
            }
          });
        });
      }

      // Progress tracking for large 3D models
      viewer.addEventListener('progress', (event) => {
        const percent = Math.round(event.detail.totalProgress * 100);
        if (progressFill) progressFill.style.width = Math.max(percent, 8) + '%';
        if (loadingStatus) loadingStatus.innerText = `Downloading 3D model... (${percent}%)`;
      });

      // 'load' fires when the model is parsed wait for first rendered frame
      viewer.addEventListener('load', () => {
        console.log('3D Model parsed waiting for first render frame');
        revealModel();
      });

      // 'model-visibility' is an extra signal some model-viewer versions emit
      viewer.addEventListener('model-visibility', (e) => {
        if (e.detail.visible) revealModel();
      });

      // Error handling
      viewer.addEventListener('error', (err) => {
        console.error('3D Model Error:', err);
        showArDiagnostic({status: 'error', message: `3D model error: ${err.detail?.type || 'unknown'}; ${err.detail?.sourceError?.message || 'No further error details supplied.'}`});
        loadHandled = true; // stop the timeout from overwriting the error
        if (loadingStatus) {
          loadingStatus.innerText = '⚠️ Failed to load 3D model.';
          loadingStatus.style.color = '#ff6b6b';
        }
        if (progressFill) progressFill.style.background = '#ff6b6b';
        // Show a retry button
        const retryBtn = document.createElement('button');
        retryBtn.innerText = '↺  Retry';
        retryBtn.style.cssText = 'margin-top:20px;padding:10px 28px;border-radius:24px;border:none;background:#D4A853;color:#0b1812;font-weight:700;font-size:14px;cursor:pointer;';
        retryBtn.onclick = () => location.reload();
        if (loadingOverlay) loadingOverlay.appendChild(retryBtn);
      });

      // 45-second hard timeout if model never fires 'load' or 'error', show a friendly message
      setTimeout(() => {
        if (!loadHandled) {
          loadHandled = true;
          if (loadingStatus) {
            loadingStatus.innerText = '⚠️ Model is taking too long. The file may be too large or unsupported.';
            loadingStatus.style.color = '#ffbb55';
          }
          const retryBtn = document.createElement('button');
          retryBtn.innerText = '↺  Retry';
          retryBtn.style.cssText = 'margin-top:20px;padding:10px 28px;border-radius:24px;border:none;background:#D4A853;color:#0b1812;font-weight:700;font-size:14px;cursor:pointer;';
          retryBtn.onclick = () => location.reload();
          if (loadingOverlay) loadingOverlay.appendChild(retryBtn);
        }
      }, 45000);
    }

    // Toggle Auto-rotation
    function toggleAutoRotate() {
      if (!viewer) return;
      const btn = document.querySelector('#rotate-btn');
      viewer.autoRotate = !viewer.autoRotate;
      btn.classList.toggle('active', viewer.autoRotate);
    }

    // Reset Camera view
    function resetCamera() {
      if (!viewer) return;
      viewer.cameraOrbit = '0deg 75deg auto';
      viewer.cameraTarget = 'auto auto auto';
    }

    // Expand / Collapse Description
    function toggleDesc(e) {
      const desc = document.getElementById('info-desc');
      if (desc) desc.classList.toggle('expanded');
    }

    // Fullscreen Toggle
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
