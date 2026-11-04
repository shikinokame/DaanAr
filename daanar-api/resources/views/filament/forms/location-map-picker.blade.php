@php
    $basePath = $getContainer()->getStatePath() ?: 'data';
    $municipalitiesJson = $municipalities ?? [];
    $showGeofenceRings = $showGeofence ?? true;
    $enableMunicipalitySync = $hasMunicipality ?? true;
    $enableAddressSync = $hasAddress ?? true;
@endphp

<style>
    .daanar-loc-picker {
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 0.75rem;
        background: rgba(17, 24, 39, 0.45);
        padding: 1rem;
    }
    html:not(.dark) .daanar-loc-picker {
        border-color: #e5e7eb;
        background: #f9fafb;
    }
    .daanar-loc-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 0.75rem;
    }
    @media (max-width: 900px) {
        .daanar-loc-grid {
            grid-template-columns: 1fr;
        }
    }
    .daanar-loc-label {
        display: block;
        font-size: 0.75rem;
        font-weight: 600;
        letter-spacing: 0.02em;
        margin-bottom: 0.35rem;
        color: #d1d5db;
    }
    html:not(.dark) .daanar-loc-label {
        color: #374151;
    }
    .daanar-loc-input-row {
        display: flex;
        gap: 0.45rem;
    }
    .daanar-loc-input {
        flex: 1;
        min-width: 0;
        border-radius: 0.5rem;
        border: 1px solid rgba(255, 255, 255, 0.14);
        background: rgba(9, 13, 22, 0.75);
        color: #f9fafb;
        font-size: 0.85rem;
        padding: 0.5rem 0.75rem;
        outline: none;
        transition: border-color 0.15s ease;
    }
    html:not(.dark) .daanar-loc-input {
        background: #ffffff;
        border-color: #d1d5db;
        color: #111827;
    }
    .daanar-loc-input:focus {
        border-color: #f59e0b;
        box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
    }
    .daanar-loc-btn {
        display: inline-flex;
        align-items: center;
        gap: 0.35rem;
        border-radius: 0.5rem;
        border: 1px solid rgba(245, 158, 11, 0.45);
        background: rgba(245, 158, 11, 0.14);
        color: #fbbf24;
        font-size: 0.78rem;
        font-weight: 600;
        padding: 0.45rem 0.8rem;
        cursor: pointer;
        white-space: nowrap;
        transition: all 0.15s ease;
    }
    html:not(.dark) .daanar-loc-btn {
        background: #fffbeb;
        border-color: #f59e0b;
        color: #b45309;
    }
    .daanar-loc-btn:hover {
        background: rgba(245, 158, 11, 0.26);
    }
    .daanar-loc-btn-secondary {
        border-color: rgba(255, 255, 255, 0.14);
        background: rgba(255, 255, 255, 0.05);
        color: #e5e7eb;
    }
    html:not(.dark) .daanar-loc-btn-secondary {
        border-color: #d1d5db;
        background: #ffffff;
        color: #374151;
    }
    .daanar-loc-btn-secondary:hover {
        background: rgba(255, 255, 255, 0.12);
    }
    html:not(.dark) .daanar-loc-btn-secondary:hover {
        background: #f3f4f6;
    }
    .daanar-loc-btn-active {
        background: #f59e0b !important;
        border-color: #f59e0b !important;
        color: #111827 !important;
    }
    .daanar-search-results {
        margin-top: 0.45rem;
        border-radius: 0.5rem;
        border: 1px solid rgba(255, 255, 255, 0.14);
        background: #111827;
        overflow: hidden;
        max-height: 210px;
        overflow-y: auto;
    }
    html:not(.dark) .daanar-search-results {
        background: #ffffff;
        border-color: #d1d5db;
    }
    .daanar-search-item {
        display: block;
        width: 100%;
        text-align: left;
        padding: 0.55rem 0.75rem;
        font-size: 0.8rem;
        color: #f3f4f6;
        background: transparent;
        border: none;
        border-bottom: 1px solid rgba(255, 255, 255, 0.07);
        cursor: pointer;
    }
    html:not(.dark) .daanar-search-item {
        color: #1f2937;
        border-bottom-color: #f3f4f6;
    }
    .daanar-search-item:last-child {
        border-bottom: none;
    }
    .daanar-search-item:hover {
        background: rgba(245, 158, 11, 0.15);
    }
    .daanar-map-wrap {
        position: relative;
        isolation: isolate;
        z-index: 1;
        margin-top: 0.75rem;
        border-radius: 0.65rem;
        overflow: hidden;
        border: 1px solid rgba(255, 255, 255, 0.14);
    }
    html:not(.dark) .daanar-map-wrap {
        border-color: #d1d5db;
    }
    .daanar-leaflet-map {
        width: 100%;
        height: 360px;
        background: #0f172a;
    }
    /* Prevent Tailwind preflight from shrinking Leaflet map tiles */
    .daanar-leaflet-map .leaflet-pane img,
    .daanar-leaflet-map .leaflet-tile {
        max-width: none !important;
        max-height: none !important;
    }
    .daanar-toolbar {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        justify-content: space-between;
        gap: 0.5rem;
        margin-top: 0.65rem;
    }
    .daanar-toolbar-group {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 0.4rem;
    }
    .daanar-legend {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 0.85rem;
        margin-top: 0.6rem;
        font-size: 0.75rem;
        color: #9ca3af;
    }
    html:not(.dark) .daanar-legend {
        color: #4b5563;
    }
    .daanar-dot {
        display: inline-block;
        width: 9px;
        height: 9px;
        border-radius: 9999px;
        margin-right: 0.3rem;
    }
    .daanar-status {
        margin-top: 0.5rem;
        font-size: 0.78rem;
        font-weight: 500;
    }
    .daanar-status-ok {
        color: #34d399;
    }
    html:not(.dark) .daanar-status-ok {
        color: #047857;
    }
    .daanar-status-err {
        color: #f87171;
    }
    html:not(.dark) .daanar-status-err {
        color: #dc2626;
    }
</style>

<div
    class="daanar-loc-picker"
    x-data="{
        lat: $wire.$entangle('{{ $basePath }}.lat'),
        lng: $wire.$entangle('{{ $basePath }}.lng'),
        @if ($enableMunicipalitySync)
        municipalityId: $wire.$entangle('{{ $basePath }}.municipality_id'),
        @else
        municipalityId: null,
        @endif
        @if ($enableAddressSync)
        address: $wire.$entangle('{{ $basePath }}.address'),
        @else
        address: null,
        @endif

        municipalities: @js($municipalitiesJson),
        showGeofence: @js($showGeofenceRings),
        hasMunicipality: @js($enableMunicipalitySync),
        hasAddress: @js($enableAddressSync),

        pasteText: '',
        searchQuery: '',
        searchResults: [],
        isSearching: false,
        isResolving: false,
        isReversing: false,
        layerMode: 'satellite',
        statusMsg: '',
        statusError: false,

        map: null,
        marker: null,
        geofenceCircle: null,
        arCircle: null,
        streetLayer: null,
        satelliteLayer: null,
        labelsLayer: null,
        isInternalUpdate: false,
        resizeObserver: null,

        async init() {
            await this.ensureLeafletLoaded();
            this.$nextTick(() => this.setupMap());

            this.$watch('lat', () => {
                if (!this.isInternalUpdate) this.syncMapFromFields(false);
            });
            this.$watch('lng', () => {
                if (!this.isInternalUpdate) this.syncMapFromFields(false);
            });

            if (this.hasMunicipality) {
                this.$watch('municipalityId', (newId) => {
                    if (!newId || !this.map) return;
                    const hasCoords = this.isValidCoord(this.lat, this.lng);
                    if (!hasCoords) {
                        this.centerOnMunicipality(true);
                    }
                });
            }
        },

        ensureLeafletLoaded() {
            if (window.L && typeof window.L.map === 'function') {
                return Promise.resolve();
            }
            if (window.__daanarLeafletPromise) {
                return window.__daanarLeafletPromise;
            }
            window.__daanarLeafletPromise = new Promise((resolve, reject) => {
                if (!document.getElementById('daanar-leaflet-css')) {
                    const link = document.createElement('link');
                    link.id = 'daanar-leaflet-css';
                    link.rel = 'stylesheet';
                    link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
                    document.head.appendChild(link);
                }
                const script = document.createElement('script');
                script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
                script.onload = () => resolve();
                script.onerror = () => reject(new Error('Failed to load map library'));
                document.head.appendChild(script);
            });
            return window.__daanarLeafletPromise;
        },

        setupMap() {
            const el = this.$refs.mapCanvas;
            if (!el || !window.L || this.map) return;

            // Default center: central Pangasinan (Dagupan / Mangaldan / Manaoag corridor)
            let startLat = 16.0550;
            let startLng = 120.4020;
            let startZoom = 12;

            if (this.isValidCoord(this.lat, this.lng)) {
                startLat = parseFloat(this.lat);
                startLng = parseFloat(this.lng);
                startZoom = 18;
            } else if (this.hasMunicipality && this.municipalityId && this.municipalities[String(this.municipalityId)]) {
                const m = this.municipalities[String(this.municipalityId)];
                startLat = parseFloat(m.lat);
                startLng = parseFloat(m.lng);
                startZoom = 15;
            }

            this.map = L.map(el, {
                center: [startLat, startLng],
                zoom: startZoom,
                zoomControl: true,
            });

            this.streetLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '&copy; OpenStreetMap',
            });

            this.satelliteLayer = L.tileLayer(
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                {
                    maxZoom: 19,
                    attribution: 'Tiles &copy; Esri',
                }
            );

            this.labelsLayer = L.tileLayer(
                'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                {
                    maxZoom: 19,
                    pane: 'overlayPane',
                }
            );

            this.applyLayerMode();

            this.map.on('click', (e) => {
                this.setCoordinates(e.latlng.lat, e.latlng.lng, {
                    fly: false,
                    message: 'Pin placed at ' + e.latlng.lat.toFixed(6) + ', ' + e.latlng.lng.toFixed(6),
                });
            });

            if (this.isValidCoord(this.lat, this.lng)) {
                this.placeOrMovePin(parseFloat(this.lat), parseFloat(this.lng));
            }

            if (typeof ResizeObserver !== 'undefined') {
                this.resizeObserver = new ResizeObserver(() => {
                    if (this.map) this.map.invalidateSize();
                });
                this.resizeObserver.observe(el);
            }
        },

        setLayer(mode) {
            this.layerMode = mode;
            this.applyLayerMode();
        },

        applyLayerMode() {
            if (!this.map) return;
            if (this.layerMode === 'satellite') {
                if (this.map.hasLayer(this.streetLayer)) this.map.removeLayer(this.streetLayer);
                if (!this.map.hasLayer(this.satelliteLayer)) this.satelliteLayer.addTo(this.map);
                if (!this.map.hasLayer(this.labelsLayer)) this.labelsLayer.addTo(this.map);
            } else {
                if (this.map.hasLayer(this.satelliteLayer)) this.map.removeLayer(this.satelliteLayer);
                if (this.map.hasLayer(this.labelsLayer)) this.map.removeLayer(this.labelsLayer);
                if (!this.map.hasLayer(this.streetLayer)) this.streetLayer.addTo(this.map);
            }
        },

        pinIcon() {
            return L.divIcon({
                className: 'daanar-custom-pin',
                html: `<svg width='34' height='42' viewBox='0 0 34 42' fill='none' xmlns='http://www.w3.org/2000/svg'>
                    <path d='M17 1C8.163 1 1 8.163 1 17C1 28.25 17 40.5 17 40.5C17 40.5 33 28.25 33 17C33 8.163 25.837 1 17 1Z' fill='#1B4332' stroke='#F59E0B' stroke-width='2.4'/>
                    <circle cx='17' cy='16.5' r='6' fill='#F59E0B'/>
                </svg>`,
                iconSize: [34, 42],
                iconAnchor: [17, 41],
            });
        },

        placeOrMovePin(latNum, lngNum) {
            if (!this.map || !window.L) return;
            const pos = [latNum, lngNum];

            if (!this.marker) {
                this.marker = L.marker(pos, {
                    draggable: true,
                    icon: this.pinIcon(),
                }).addTo(this.map);

                this.marker.on('dragend', (ev) => {
                    const p = ev.target.getLatLng();
                    this.setCoordinates(p.lat, p.lng, {
                        fly: false,
                        message: 'Pin dragged to ' + p.lat.toFixed(6) + ', ' + p.lng.toFixed(6),
                    });
                });
            } else {
                this.marker.setLatLng(pos);
            }

            if (this.showGeofence) {
                if (!this.geofenceCircle) {
                    this.geofenceCircle = L.circle(pos, {
                        radius: 100,
                        color: '#10b981',
                        weight: 2,
                        dashArray: '6, 6',
                        fillColor: '#10b981',
                        fillOpacity: 0.12,
                        interactive: false,
                    }).addTo(this.map);
                } else {
                    this.geofenceCircle.setLatLng(pos);
                }

                if (!this.arCircle) {
                    this.arCircle = L.circle(pos, {
                        radius: 50,
                        color: '#f59e0b',
                        weight: 2,
                        fillColor: '#f59e0b',
                        fillOpacity: 0.16,
                        interactive: false,
                    }).addTo(this.map);
                } else {
                    this.arCircle.setLatLng(pos);
                }
            }
        },

        setCoordinates(latNum, lngNum, opts = {}) {
            if (!this.isValidCoord(latNum, lngNum)) {
                this.setStatus('Coordinates are outside valid latitude/longitude bounds.', true);
                return;
            }
            const cleanLat = Number(latNum).toFixed(8);
            const cleanLng = Number(lngNum).toFixed(8);

            this.isInternalUpdate = true;
            this.lat = cleanLat;
            this.lng = cleanLng;

            this.placeOrMovePin(parseFloat(cleanLat), parseFloat(cleanLng));

            if (opts.fly && this.map) {
                this.map.flyTo([parseFloat(cleanLat), parseFloat(cleanLng)], opts.zoom || 18, {
                    duration: 0.75,
                });
            }

            if (opts.message) {
                this.setStatus(opts.message, false);
            }

            this.$nextTick(() => {
                this.isInternalUpdate = false;
            });
        },

        syncMapFromFields(fly = false) {
            if (!this.isValidCoord(this.lat, this.lng) || !this.map) return;
            const latNum = parseFloat(this.lat);
            const lngNum = parseFloat(this.lng);
            this.placeOrMovePin(latNum, lngNum);
            if (fly) {
                this.map.flyTo([latNum, lngNum], 18, { duration: 0.6 });
            } else {
                this.map.panTo([latNum, lngNum]);
            }
        },

        isValidCoord(latVal, lngVal) {
            if (latVal === null || latVal === '' || lngVal === null || lngVal === '') return false;
            const la = Number(latVal);
            const ln = Number(lngVal);
            return Number.isFinite(la) && Number.isFinite(ln) && la >= -90 && la <= 90 && ln >= -180 && ln <= 180;
        },

        setStatus(msg, isError = false) {
            this.statusMsg = msg;
            this.statusError = isError;
        },

        onPasteEvent() {
            setTimeout(() => {
                if (this.pasteText.trim() !== '') {
                    this.applyPastedInput();
                }
            }, 80);
        },

        async applyPastedInput() {
            const raw = (this.pasteText || '').trim();
            if (!raw) return;

            const direct = this.parseCoordinateString(raw);
            if (direct) {
                this.setCoordinates(direct.lat, direct.lng, {
                    fly: true,
                    zoom: 18,
                    message: 'Extracted exact coordinates (' + direct.source + '): ' + direct.lat.toFixed(6) + ', ' + direct.lng.toFixed(6),
                });
                return;
            }

            // Handle shortened Google Maps share links (maps.app.goo.gl / goo.gl/maps)
            if (/^https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl|(?:www\.|maps\.)?google\.com)/i.test(raw)) {
                this.isResolving = true;
                this.setStatus('Resolving Google Maps link...', false);
                try {
                    const url = '{{ route('cms.location.resolve-url', [], false) }}?url=' + encodeURIComponent(raw);
                    const resp = await fetch(url, { headers: { 'Accept': 'application/json' } });
                    const data = await resp.json();
                    if (resp.ok && data.lat !== null && data.lng !== null) {
                        this.setCoordinates(data.lat, data.lng, {
                            fly: true,
                            zoom: 18,
                            message: 'Extracted coordinates from Google Maps short link.',
                        });
                    } else {
                        this.setStatus(data.error || 'Could not find coordinates in that link.', true);
                    }
                } catch (err) {
                    this.setStatus('Could not resolve short link. Paste full URL or coordinates instead.', true);
                } finally {
                    this.isResolving = false;
                }
                return;
            }

            this.setStatus('Could not detect coordinates. Paste a Google Maps URL or lat, lng pair (e.g. 16.0442, 120.4861).', true);
        },

        parseCoordinateString(input) {
            let decoded = input;
            try {
                decoded = decodeURIComponent(input);
            } catch (_) {}

            // 1. Exact Google Maps place pin (!3dLAT!4dLNG) - avoids shifted @camera center
            const pinMatches = [...decoded.matchAll(/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/g)];
            if (pinMatches.length > 0) {
                const last = pinMatches[pinMatches.length - 1];
                const la = parseFloat(last[1]);
                const ln = parseFloat(last[2]);
                if (this.isValidCoord(la, ln)) {
                    return { lat: la, lng: ln, source: 'Google Maps place pin' };
                }
            }

            // 2. Query / ll / center URL parameters (?q=lat,lng or &ll=lat,lng)
            const queryMatch = decoded.match(/[?&](?:q|ll|query|center|destination|daddr)=(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/i);
            if (queryMatch) {
                const la = parseFloat(queryMatch[1]);
                const ln = parseFloat(queryMatch[2]);
                if (this.isValidCoord(la, ln)) {
                    return { lat: la, lng: ln, source: 'Google Maps query' };
                }
            }

            // 3. Google Maps @lat,lng viewport URL
            const atMatch = decoded.match(/@(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/);
            if (atMatch) {
                const la = parseFloat(atMatch[1]);
                const ln = parseFloat(atMatch[2]);
                if (this.isValidCoord(la, ln)) {
                    return { lat: la, lng: ln, source: 'Google Maps URL' };
                }
            }

            // 4. Degrees Minutes Seconds (e.g. 16°02'39.2\"N 120°29'10.0\"E)
            const dmsRegex = /(\d{1,3})[°\s]+(\d{1,2})['′\s]+(\d{1,2}(?:\.\d+)?)[″\"\s]*([NSns])[,\s]+(\d{1,3})[°\s]+(\d{1,2})['′\s]+(\d{1,2}(?:\.\d+)?)[″\"\s]*([EWew])/;
            const dmsMatch = decoded.match(dmsRegex);
            if (dmsMatch) {
                let la = parseInt(dmsMatch[1], 10) + parseInt(dmsMatch[2], 10) / 60 + parseFloat(dmsMatch[3]) / 3600;
                if (dmsMatch[4].toUpperCase() === 'S') la = -la;
                let ln = parseInt(dmsMatch[5], 10) + parseInt(dmsMatch[6], 10) / 60 + parseFloat(dmsMatch[7]) / 3600;
                if (dmsMatch[8].toUpperCase() === 'W') ln = -ln;
                if (this.isValidCoord(la, ln)) {
                    return { lat: la, lng: ln, source: 'DMS coordinates' };
                }
            }

            // 5. Plain decimal pair: 16.044215, 120.486102 or (16.044215, 120.486102)
            const pairMatch = decoded.match(/^\s*\(?\s*(-?\d{1,2}(?:\.\d+)?)\s*[,\s]\s*(-?\d{1,3}(?:\.\d+)?)\s*\)?\s*$/);
            if (pairMatch) {
                const la = parseFloat(pairMatch[1]);
                const ln = parseFloat(pairMatch[2]);
                if (this.isValidCoord(la, ln)) {
                    return { lat: la, lng: ln, source: 'coordinate pair' };
                }
            }

            return null;
        },

        async runPlaceSearch() {
            const q = (this.searchQuery || '').trim();
            if (q.length < 2) {
                this.searchResults = [];
                return;
            }
            this.isSearching = true;
            this.setStatus('', false);

            try {
                const endpoint = '{{ route('cms.location.search', [], false) }}?q=' + encodeURIComponent(q);
                const resp = await fetch(endpoint, { headers: { 'Accept': 'application/json' } });
                if (resp.ok) {
                    const data = await resp.json();
                    this.searchResults = data.results || [];
                } else {
                    this.searchResults = [];
                }

                if (this.searchResults.length === 0) {
                    this.setStatus('No matching places found. Try adding the town name (e.g. Manaoag, Pangasinan) or paste a Google Maps link.', true);
                }
            } catch (_) {
                this.setStatus('Place search failed. Check your internet connection or paste coordinates directly.', true);
            } finally {
                this.isSearching = false;
            }
        },

        selectSearchResult(item) {
            this.searchResults = [];
            this.searchQuery = item.name || item.display_name;
            this.setCoordinates(item.lat, item.lng, {
                fly: true,
                zoom: 18,
                message: 'Selected: ' + (item.name || item.display_name),
            });

            if (this.hasAddress && (!this.address || String(this.address).trim() === '') && item.display_name) {
                this.address = item.display_name.slice(0, 255);
            }
        },

        centerOnMunicipality(silentIfMissing = false) {
            if (!this.hasMunicipality || !this.municipalityId) {
                if (!silentIfMissing) {
                    this.setStatus('Select a Municipality in Basic Information first.', true);
                }
                return;
            }
            const muni = this.municipalities[String(this.municipalityId)];
            if (!muni || !this.map) return;

            this.map.flyTo([parseFloat(muni.lat), parseFloat(muni.lng)], 15, { duration: 0.7 });
            this.setStatus('Map centered on ' + muni.name + '. Click on the exact landmark spot to drop the pin.', false);
        },

        useBrowserGps() {
            if (!navigator.geolocation) {
                this.setStatus('Geolocation is not supported in this browser.', true);
                return;
            }
            this.setStatus('Reading current GPS position...', false);
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    this.setCoordinates(pos.coords.latitude, pos.coords.longitude, {
                        fly: true,
                        zoom: 18,
                        message: 'Pin set to your current GPS position.',
                    });
                },
                () => {
                    this.setStatus('Unable to read GPS location. Check browser location permission.', true);
                },
                { enableHighAccuracy: true, timeout: 10000 }
            );
        },

        async fillAddressFromPin() {
            if (!this.isValidCoord(this.lat, this.lng)) {
                this.setStatus('Drop a pin on the map first before fetching the address.', true);
                return;
            }
            this.isReversing = true;
            try {
                const url = '{{ route('cms.location.reverse', [], false) }}?lat=' + encodeURIComponent(this.lat) + '&lng=' + encodeURIComponent(this.lng);
                const resp = await fetch(url, { headers: { 'Accept': 'application/json' } });
                const data = await resp.json();
                if (resp.ok && data.address) {
                    this.address = String(data.address).slice(0, 255);
                    this.setStatus('Address field updated from pin location.', false);
                } else {
                    this.setStatus('Could not find a street address for this pin.', true);
                }
            } catch (_) {
                this.setStatus('Reverse geocoding failed.', true);
            } finally {
                this.isReversing = false;
            }
        }
    }"
>
    <div class="daanar-loc-grid">
        {{-- 1. Quick Paste: Google Maps URL or Coordinate Pair --}}
        <div>
            <label class="daanar-loc-label">Quick Paste (Google Maps Link or Coordinates)</label>
            <div class="daanar-loc-input-row">
                <input
                    type="text"
                    class="daanar-loc-input"
                    x-model="pasteText"
                    @paste="onPasteEvent()"
                    @keydown.enter.prevent="applyPastedInput()"
                    placeholder="Paste Google Maps URL or 16.0442, 120.4861"
                />
                <button
                    type="button"
                    class="daanar-loc-btn"
                    @click="applyPastedInput()"
                    :disabled="isResolving"
                >
                    <span x-text="isResolving ? 'Parsing...' : 'Apply'"></span>
                </button>
            </div>
        </div>

        {{-- 2. Place Search (Nominatim / OpenStreetMap) --}}
        <div>
            <label class="daanar-loc-label">Search Place or Landmark Name</label>
            <div class="daanar-loc-input-row">
                <input
                    type="text"
                    class="daanar-loc-input"
                    x-model="searchQuery"
                    @keydown.enter.prevent="runPlaceSearch()"
                    placeholder="e.g. Minor Basilica Manaoag, Dagupan Plaza..."
                />
                <button
                    type="button"
                    class="daanar-loc-btn"
                    @click="runPlaceSearch()"
                    :disabled="isSearching"
                >
                    <span x-text="isSearching ? 'Searching...' : 'Search'"></span>
                </button>
            </div>

            <template x-if="searchResults.length > 0">
                <div class="daanar-search-results">
                    <template x-for="(item, idx) in searchResults" :key="idx">
                        <button
                            type="button"
                            class="daanar-search-item"
                            @click="selectSearchResult(item)"
                        >
                            <div style="font-weight: 600;" x-text="item.name || item.display_name.split(',')[0]"></div>
                            <div style="font-size: 0.72rem; opacity: 0.75;" x-text="item.display_name"></div>
                        </button>
                    </template>
                </div>
            </template>
        </div>
    </div>

    {{-- Toolbar: Map View Toggle + Quick Helpers --}}
    <div class="daanar-toolbar">
        <div class="daanar-toolbar-group">
            <button
                type="button"
                class="daanar-loc-btn daanar-loc-btn-secondary"
                :class="{ 'daanar-loc-btn-active': layerMode === 'satellite' }"
                @click="setLayer('satellite')"
            >
                Satellite View
            </button>
            <button
                type="button"
                class="daanar-loc-btn daanar-loc-btn-secondary"
                :class="{ 'daanar-loc-btn-active': layerMode === 'street' }"
                @click="setLayer('street')"
            >
                Street Map
            </button>
        </div>

        <div class="daanar-toolbar-group">
            <template x-if="hasMunicipality">
                <button
                    type="button"
                    class="daanar-loc-btn daanar-loc-btn-secondary"
                    @click="centerOnMunicipality(false)"
                >
                    Center on Municipality
                </button>
            </template>

            <button
                type="button"
                class="daanar-loc-btn daanar-loc-btn-secondary"
                @click="useBrowserGps()"
            >
                Use My GPS
            </button>

            <template x-if="hasAddress">
                <button
                    type="button"
                    class="daanar-loc-btn daanar-loc-btn-secondary"
                    @click="fillAddressFromPin()"
                    :disabled="isReversing"
                >
                    <span x-text="isReversing ? 'Fetching...' : 'Fill Address from Pin'"></span>
                </button>
            </template>
        </div>
    </div>

    {{-- Interactive Leaflet Map Canvas --}}
    <div class="daanar-map-wrap" wire:ignore>
        <div x-ref="mapCanvas" class="daanar-leaflet-map"></div>
    </div>

    {{-- Legend & Status --}}
    <div class="daanar-legend">
        <span>Click anywhere on the map or drag the pin to set exact coordinates.</span>
        @if ($showGeofenceRings)
            <span><span class="daanar-dot" style="background: #f59e0b;"></span>50m AR Prompt Zone</span>
            <span><span class="daanar-dot" style="background: #10b981;"></span>100m Visit Geofence</span>
        @endif
    </div>

    <template x-if="statusMsg">
        <div
            class="daanar-status"
            :class="statusError ? 'daanar-status-err' : 'daanar-status-ok'"
            x-text="statusMsg"
        ></div>
    </template>
</div>
