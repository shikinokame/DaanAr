<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <title>DaanAR — Camera Test</title>
  <script src="https://aframe.io/releases/1.5.0/aframe.min.js"></script>
  <script src="https://raw.githack.com/AR-js-org/AR.js/master/aframe/build/aframe-ar.js"></script>
  <style>
    * { margin: 0; padding: 0; }
    body { overflow: hidden; font-family: sans-serif; background: #000; }
    #status {
      position: fixed; top: 16px; left: 50%; transform: translateX(-50%);
      background: rgba(27,67,50,0.9); color: #fff;
      padding: 10px 20px; border-radius: 20px; font-size: 14px;
      z-index: 9999; text-align: center; backdrop-filter: blur(8px);
      border: 1px solid rgba(212,168,83,0.5);
    }
    #status span { color: #D4A853; font-weight: bold; }
    #panel {
      position: fixed; bottom: 20px; left: 16px; right: 16px;
      background: rgba(27,67,50,0.88); color: #fff;
      padding: 16px 20px; border-radius: 16px; z-index: 9999;
      border: 1px solid rgba(212,168,83,0.4);
    }
    #panel h3 { color: #D4A853; margin-bottom: 4px; }
    #panel p { font-size: 12px; opacity: 0.8; }
    .a-enter-vr, .a-loader-title { display: none !important; }
  </style>
</head>
<body>
  <div id="status">🔲 Point camera at <span>HIRO marker</span> to test AR</div>

  <a-scene
    embedded
    arjs="sourceType: webcam; debugUIEnabled: false; detectionMode: mono_and_matrix; matrixCodeType: 3x3;"
    vr-mode-ui="enabled: false"
    loading-screen="enabled: false">

    <a-marker preset="hiro">
      <!-- Spinning heritage building stand-in -->
      <a-entity position="0 0.5 0"
        animation="property: rotation; to: 0 360 0; loop: true; dur: 6000; easing: linear">
        <a-box color="#1B4332" depth="0.8" height="0.1" width="0.8" position="0 0 0"></a-box>
        <a-box color="#2D6A4F" depth="0.55" height="0.35" width="0.55" position="0 0.225 0"></a-box>
        <a-box color="#1B4332" depth="0.3" height="0.25" width="0.3" position="0 0.525 0"></a-box>
        <a-cone color="#D4A853" radius-bottom="0.22" radius-top="0.02" height="0.3" position="0 0.8 0"></a-cone>
      </a-entity>
      <a-text value="DaanAR Test" align="center" color="#D4A853"
        position="0 1.6 0" scale="0.6 0.6 0.6"></a-text>
    </a-marker>

    <a-entity camera></a-entity>
  </a-scene>

  <div id="panel">
    <h3>✅ AR Camera Test</h3>
    <p>If you can see the camera feed, permissions are working.<br>
       Print or display the HIRO marker image and point your camera at it to see the 3D model.</p>
  </div>

  <script>
    const marker = document.querySelector('a-marker');
    const status = document.getElementById('status');
    marker.addEventListener('markerFound', () => {
      status.innerHTML = '✅ Marker detected! <span>AR is working!</span>';
      status.style.background = 'rgba(27,67,50,0.95)';
    });
    marker.addEventListener('markerLost', () => {
      status.innerHTML = '🔲 Point camera at <span>HIRO marker</span> to test AR';
    });
  </script>
</body>
</html>
