@php
    $basePath = $getContainer()->getStatePath() ?: 'data';
    $municipalitiesJson = $municipalities ?? [];
    $showGeofenceRings = (bool) ($showGeofence ?? true);
    $enableMunicipalitySync = (bool) ($hasMunicipality ?? true);
    $enableAddressSync = (bool) ($hasAddress ?? true);
    $googleMapsApiKey = (string) config('services.google_maps.key', '');

    $pickerConfig = [
        'googleMapsApiKey' => $googleMapsApiKey,
        'municipalities' => $municipalitiesJson,
        'searchUrl' => route('cms.location.search', [], false),
        'reverseUrl' => route('cms.location.reverse', [], false),
        'resolveUrl' => route('cms.location.resolve-url', [], false),
    ];
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
    .daanar-gmap-canvas {
        width: 100%;
        height: 390px;
        background: #0f172a;
    }
    /* Prevent Tailwind preflight from distorting Google Maps icons and tiles */
    .daanar-gmap-canvas img {
        max-width: none !important;
        max-height: none !important;
    }
    /* Keep Google Places Autocomplete dropdown above Filament layers */
    .pac-container {
        z-index: 99999 !important;
        border-radius: 0.5rem;
        margin-top: 4px;
        font-family: inherit;
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

<script>
    if (!window.daanarLocationPicker) {
        window.daanarLocationPicker = function (params) {
            return {
                lat: params.lat,
                lng: params.lng,
                municipalityId: params.municipalityId,
                address: params.address,
                showGeofence: Boolean(params.showGeofence),
                hasMunicipality: Boolean(params.hasMunicipality),
                hasAddress: Boolean(params.hasAddress),

                googleMapsApiKey: '',
                municipalities: {},
                searchUrl: '/cms-tools/location/search',
                reverseUrl: '/cms-tools/location/reverse',
                resolveUrl: '/cms-tools/location/resolve-url',

                pasteText: '',
                searchQuery: '',
                isSearching: false,
                isResolving: false,
                isReversing: false,
                layerMode: 'hybrid',
                statusMsg: '',
                statusError: false,

                map: null,
                marker: null,
                geocoder: null,
                autocomplete: null,
                geofenceCircle: null,
                arCircle: null,
                isInternalUpdate: false,

                async init() {
                    if (this.$refs.configData) {
                        try {
                            const cfg = JSON.parse(this.$refs.configData.textContent || '{}');
                            this.googleMapsApiKey = cfg.googleMapsApiKey || '';
                            this.municipalities = cfg.municipalities || {};
                            if (cfg.searchUrl) this.searchUrl = cfg.searchUrl;
                            if (cfg.reverseUrl) this.reverseUrl = cfg.reverseUrl;
                            if (cfg.resolveUrl) this.resolveUrl = cfg.resolveUrl;
                        } catch (_) {}
                    }

                    const self = this;
                    window.gm_authFailure = function () {
                        self.setStatus(
                            'Google Maps key error: check Maps JavaScript API & billing restrictions in Google Cloud Console.',
                            true
                        );
                    };

                    try {
                        await this.ensureGoogleMapsLoaded();
                        this.$nextTick(() => this.setupMap());
                    } catch (err) {
                        this.setStatus('Unable to load Google Maps JavaScript SDK. Check internet connection or API key.', true);
                    }

                    this.$watch('lat', () => {
                        if (!this.isInternalUpdate) this.syncMapFromFields(false);
                    });
                    this.$watch('lng', () => {
                        if (!this.isInternalUpdate) this.syncMapFromFields(false);
                    });

                    if (this.hasMunicipality) {
                        this.$watch('municipalityId', (newId) => {
                            if (!newId || !this.map) return;
                            if (!this.isValidCoord(this.lat, this.lng)) {
                                this.centerOnMunicipality(true);
                            }
                        });
                    }
                },

                ensureGoogleMapsLoaded() {
                    if (window.google && window.google.maps && window.google.maps.Map) {
                        return Promise.resolve();
                    }
                    if (window.__daanarGoogleMapsPromise) {
                        return window.__daanarGoogleMapsPromise;
                    }
                    if (!this.googleMapsApiKey) {
                        return Promise.reject(new Error('Missing GOOGLE_MAPS_API_KEY'));
                    }

                    const key = this.googleMapsApiKey;
                    window.__daanarGoogleMapsPromise = new Promise((resolve, reject) => {
                        window.__daanarGmapsReady = function () {
                            resolve();
                        };
                        const script = document.createElement('script');
                        script.src = 'https://maps.googleapis.com/maps/api/js?key=' +
                            encodeURIComponent(key) +
                            '&libraries=places&callback=__daanarGmapsReady';
                        script.async = true;
                        script.defer = true;
                        script.onerror = () => reject(new Error('Failed to load Google Maps script'));
                        document.head.appendChild(script);
                    });

                    return window.__daanarGoogleMapsPromise;
                },

                setupMap() {
                    const el = this.$refs.mapCanvas;
                    if (!el || !(window.google && window.google.maps) || this.map) return;

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

                    this.geocoder = new google.maps.Geocoder();

                    this.map = new google.maps.Map(el, {
                        center: { lat: startLat, lng: startLng },
                        zoom: startZoom,
                        mapTypeId: this.layerMode,
                        mapTypeControl: false,
                        streetViewControl: true,
                        fullscreenControl: true,
                        zoomControl: true,
                        gestureHandling: 'greedy',
                    });

                    // Click anywhere on map or directly on a Google Maps POI icon
                    this.map.addListener('click', (e) => {
                        if (!e.latLng) return;
                        const clickedLat = e.latLng.lat();
                        const clickedLng = e.latLng.lng();

                        if (e.placeId) {
                            e.stop();
                            this.setCoordinates(clickedLat, clickedLng, {
                                fly: false,
                                message: 'Pinned Google Maps place at ' + clickedLat.toFixed(6) + ', ' + clickedLng.toFixed(6),
                            });
                            if (this.hasAddress && (!this.address || String(this.address).trim() === '') && this.geocoder) {
                                this.geocoder.geocode({ placeId: e.placeId }, (results, status) => {
                                    if (status === 'OK' && results && results[0] && results[0].formatted_address) {
                                        this.address = results[0].formatted_address.slice(0, 255);
                                    }
                                });
                            }
                        } else {
                            this.setCoordinates(clickedLat, clickedLng, {
                                fly: false,
                                message: 'Pin placed at ' + clickedLat.toFixed(6) + ', ' + clickedLng.toFixed(6),
                            });
                        }
                    });

                    if (this.isValidCoord(this.lat, this.lng)) {
                        this.placeOrMovePin(parseFloat(this.lat), parseFloat(this.lng));
                    }

                    this.setupPlacesAutocomplete();
                },

                setupPlacesAutocomplete() {
                    const inputEl = this.$refs.searchInput;
                    if (!inputEl || !(window.google && window.google.maps && window.google.maps.places)) return;

                    const pangasinanBounds = new google.maps.LatLngBounds(
                        { lat: 15.65, lng: 119.70 },
                        { lat: 16.45, lng: 120.90 }
                    );

                    this.autocomplete = new google.maps.places.Autocomplete(inputEl, {
                        bounds: pangasinanBounds,
                        strictBounds: false,
                        componentRestrictions: { country: 'ph' },
                        fields: ['geometry', 'name', 'formatted_address'],
                    });

                    this.autocomplete.addListener('place_changed', () => {
                        const place = this.autocomplete.getPlace();
                        if (!place || !place.geometry || !place.geometry.location) {
                            this.runPlaceSearch();
                            return;
                        }
                        const la = place.geometry.location.lat();
                        const ln = place.geometry.location.lng();
                        this.searchQuery = inputEl.value;

                        this.setCoordinates(la, ln, {
                            fly: true,
                            zoom: 18,
                            message: 'Selected Google Place: ' + (place.name || place.formatted_address || ''),
                        });

                        if (this.hasAddress && (!this.address || String(this.address).trim() === '') && place.formatted_address) {
                            this.address = place.formatted_address.slice(0, 255);
                        }
                    });
                },

                setLayer(mode) {
                    this.layerMode = mode;
                    if (this.map) {
                        this.map.setMapTypeId(mode);
                    }
                },

                placeOrMovePin(latNum, lngNum) {
                    if (!this.map || !(window.google && window.google.maps)) return;
                    const pos = { lat: latNum, lng: lngNum };

                    if (!this.marker) {
                        this.marker = new google.maps.Marker({
                            position: pos,
                            map: this.map,
                            draggable: true,
                            animation: google.maps.Animation.DROP,
                        });

                        this.marker.addListener('dragend', () => {
                            const p = this.marker.getPosition();
                            if (!p) return;
                            this.setCoordinates(p.lat(), p.lng(), {
                                fly: false,
                                message: 'Pin dragged to ' + p.lat().toFixed(6) + ', ' + p.lng().toFixed(6),
                            });
                        });
                    } else {
                        this.marker.setPosition(pos);
                    }

                    if (this.showGeofence) {
                        if (!this.geofenceCircle) {
                            this.geofenceCircle = new google.maps.Circle({
                                map: this.map,
                                center: pos,
                                radius: 100,
                                strokeColor: '#10b981',
                                strokeOpacity: 0.9,
                                strokeWeight: 2,
                                fillColor: '#10b981',
                                fillOpacity: 0.14,
                                clickable: false,
                            });
                        } else {
                            this.geofenceCircle.setCenter(pos);
                        }

                        if (!this.arCircle) {
                            this.arCircle = new google.maps.Circle({
                                map: this.map,
                                center: pos,
                                radius: 50,
                                strokeColor: '#f59e0b',
                                strokeOpacity: 0.95,
                                strokeWeight: 2,
                                fillColor: '#f59e0b',
                                fillOpacity: 0.2,
                                clickable: false,
                            });
                        } else {
                            this.arCircle.setCenter(pos);
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
                        this.map.panTo({ lat: parseFloat(cleanLat), lng: parseFloat(cleanLng) });
                        this.map.setZoom(opts.zoom || 18);
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
                    this.map.panTo({ lat: latNum, lng: lngNum });
                    if (fly) {
                        this.map.setZoom(18);
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

                    if (/^https?:\/\/(?:maps\.app\.goo\.gl|goo\.gl|(?:www\.|maps\.)?google\.com)/i.test(raw)) {
                        this.isResolving = true;
                        this.setStatus('Resolving Google Maps link...', false);
                        try {
                            const url = this.resolveUrl + '?url=' + encodeURIComponent(raw);
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
                        } catch (_) {
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

                    const pinMatches = [...decoded.matchAll(/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/g)];
                    if (pinMatches.length > 0) {
                        const last = pinMatches[pinMatches.length - 1];
                        const la = parseFloat(last[1]);
                        const ln = parseFloat(last[2]);
                        if (this.isValidCoord(la, ln)) {
                            return { lat: la, lng: ln, source: 'Google Maps place pin' };
                        }
                    }

                    const queryMatch = decoded.match(/[?&](?:q|ll|query|center|destination|daddr)=(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/i);
                    if (queryMatch) {
                        const la = parseFloat(queryMatch[1]);
                        const ln = parseFloat(queryMatch[2]);
                        if (this.isValidCoord(la, ln)) {
                            return { lat: la, lng: ln, source: 'Google Maps query' };
                        }
                    }

                    const atMatch = decoded.match(/@(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/);
                    if (atMatch) {
                        const la = parseFloat(atMatch[1]);
                        const ln = parseFloat(atMatch[2]);
                        if (this.isValidCoord(la, ln)) {
                            return { lat: la, lng: ln, source: 'Google Maps URL' };
                        }
                    }

                    const dmsRegex = /(\d{1,3})[°\s]+(\d{1,2})['′\s]+(\d{1,2}(?:\.\d+)?)[″"\s]*([NSns])[,\s]+(\d{1,3})[°\s]+(\d{1,2})['′\s]+(\d{1,2}(?:\.\d+)?)[″"\s]*([EWew])/;
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

                runPlaceSearch() {
                    const inputEl = this.$refs.searchInput;
                    const q = ((inputEl ? inputEl.value : this.searchQuery) || '').trim();
                    if (q.length < 2) return;

                    if (!this.geocoder) {
                        this.setStatus('Google Maps is still loading. Try again in a moment.', true);
                        return;
                    }

                    this.isSearching = true;
                    const searchAddress = /pangasinan|philippines/i.test(q) ? q : (q + ', Pangasinan, Philippines');

                    this.geocoder.geocode(
                        {
                            address: searchAddress,
                            region: 'PH',
                        },
                        (results, status) => {
                            this.isSearching = false;
                            if (status === 'OK' && results && results[0] && results[0].geometry) {
                                const loc = results[0].geometry.location;
                                this.setCoordinates(loc.lat(), loc.lng(), {
                                    fly: true,
                                    zoom: 18,
                                    message: 'Found: ' + (results[0].formatted_address || q),
                                });
                                if (this.hasAddress && (!this.address || String(this.address).trim() === '') && results[0].formatted_address) {
                                    this.address = results[0].formatted_address.slice(0, 255);
                                }
                            } else {
                                this.setStatus('Place not found. Try picking from the dropdown suggestions or adding the town name.', true);
                            }
                        }
                    );
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

                    this.map.panTo({ lat: parseFloat(muni.lat), lng: parseFloat(muni.lng) });
                    this.map.setZoom(15);
                    this.setStatus('Map centered on ' + muni.name + '. Click any building or landmark icon on the map to drop the pin.', false);
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

                fillAddressFromPin() {
                    if (!this.isValidCoord(this.lat, this.lng)) {
                        this.setStatus('Drop a pin on the map first before fetching the address.', true);
                        return;
                    }
                    if (!this.geocoder) return;

                    this.isReversing = true;
                    this.geocoder.geocode(
                        { location: { lat: parseFloat(this.lat), lng: parseFloat(this.lng) } },
                        (results, status) => {
                            this.isReversing = false;
                            if (status === 'OK' && results && results[0] && results[0].formatted_address) {
                                this.address = results[0].formatted_address.slice(0, 255);
                                this.setStatus('Address field updated from Google Geocoding.', false);
                            } else {
                                this.setStatus('Could not resolve street address for this pin.', true);
                            }
                        }
                    );
                }
            };
        };
    }
</script>

<div
    class="daanar-loc-picker"
    x-data="daanarLocationPicker({
        lat: $wire.$entangle('{{ $basePath }}.lat'),
        lng: $wire.$entangle('{{ $basePath }}.lng'),
        municipalityId: {!! $enableMunicipalitySync ? "\$wire.\$entangle('{$basePath}.municipality_id')" : 'null' !!},
        address: {!! $enableAddressSync ? "\$wire.\$entangle('{$basePath}.address')" : 'null' !!},
        showGeofence: {{ $showGeofenceRings ? 'true' : 'false' }},
        hasMunicipality: {{ $enableMunicipalitySync ? 'true' : 'false' }},
        hasAddress: {{ $enableAddressSync ? 'true' : 'false' }}
    })"
>
    <script type="application/json" x-ref="configData">@json($pickerConfig)</script>

    <div class="daanar-loc-grid">
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
                    <span x-text="isResolving ? 'Parsing...' : 'Apply'">Apply</span>
                </button>
            </div>
        </div>

        <div wire:ignore>
            <label class="daanar-loc-label">Google Places Search</label>
            <div class="daanar-loc-input-row">
                <input
                    type="text"
                    x-ref="searchInput"
                    class="daanar-loc-input"
                    @keydown.enter.prevent="runPlaceSearch()"
                    placeholder="Search church, plaza, or street in Pangasinan..."
                />
                <button
                    type="button"
                    class="daanar-loc-btn"
                    @click="runPlaceSearch()"
                    :disabled="isSearching"
                >
                    <span x-text="isSearching ? 'Searching...' : 'Search'">Search</span>
                </button>
            </div>
        </div>
    </div>

    <div class="daanar-toolbar">
        <div class="daanar-toolbar-group">
            <button
                type="button"
                class="daanar-loc-btn daanar-loc-btn-secondary"
                :class="{ 'daanar-loc-btn-active': layerMode === 'hybrid' }"
                @click="setLayer('hybrid')"
            >
                Satellite Hybrid
            </button>
            <button
                type="button"
                class="daanar-loc-btn daanar-loc-btn-secondary"
                :class="{ 'daanar-loc-btn-active': layerMode === 'roadmap' }"
                @click="setLayer('roadmap')"
            >
                Street Map
            </button>
        </div>

        <div class="daanar-toolbar-group">
            @if ($enableMunicipalitySync)
                <button
                    type="button"
                    class="daanar-loc-btn daanar-loc-btn-secondary"
                    @click="centerOnMunicipality(false)"
                >
                    Center on Municipality
                </button>
            @endif

            <button
                type="button"
                class="daanar-loc-btn daanar-loc-btn-secondary"
                @click="useBrowserGps()"
            >
                Use My GPS
            </button>

            @if ($enableAddressSync)
                <button
                    type="button"
                    class="daanar-loc-btn daanar-loc-btn-secondary"
                    @click="fillAddressFromPin()"
                    :disabled="isReversing"
                >
                    <span x-text="isReversing ? 'Fetching...' : 'Fill Address from Pin'">Fill Address from Pin</span>
                </button>
            @endif
        </div>
    </div>

    <div class="daanar-map-wrap" wire:ignore>
        <div x-ref="mapCanvas" class="daanar-gmap-canvas"></div>
    </div>

    <div class="daanar-legend">
        <span>Click any building/icon on Google Maps or drag the pin to set exact coordinates.</span>
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
