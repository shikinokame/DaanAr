# Google routing migration

The app requests live Google Routes through `POST /api/v1/routes/compute`.
The map, trail navigation and camera walking guide share this service. WALK,
DRIVE and BICYCLE are explicit modes; there is no ORS/OSRM fallback. Existing
legacy trail segments are not used as walking directions. Google results are
kept only in the current navigation session, not persisted to offline storage.

## Backend setup

1. Enable Routes API and billing in the DaanAR Google Cloud project.
2. Create a server key restricted to Routes API. Do not use an Android-only or
   HTTP-referrer-restricted Maps display key for the backend. When the backend
   has a fixed outbound IP, restrict the key to that IP as well.
3. Set `GOOGLE_ROUTES_API_KEY` in the Railway **backend service** variables and
   apply the deployment. Never commit the key or put it in the APK.
4. `GOOGLE_ROUTES_DAILY_LIMIT` defaults to 1000 requests across the app per
   limiter day. The endpoint also limits each user to 12 requests/minute and
   each IP to 40/minute. Configure Google Cloud quotas to set the desired hard
   provider limit. Laravel counters depend on the configured cache store;
   restarting ephemeral cache storage may reset them.
5. Registered online users send their existing Sanctum bearer token. Anonymous
   requests receive 401 before Google is contacted. Offline-only registrations
   need to sign in online before requesting directions.

## Refresh and presentation

- New navigation refreshes a location fix older than 20 seconds.
- Map, trail and camera route refreshes use the same policy: at least 15 seconds
  between attempts; off-route fixes trigger a refresh; within 150 m of the
  destination, moving at least 10 m permits a refresh even on the existing route.
  Elsewhere, moving 25 m and waiting 60 seconds permits a refresh.
- Fixes with accuracy worse than 40 m do not trigger refreshes. Stationary users
  do not repeatedly request a new route solely due to elapsed time.
- The displayed active route begins at the projected current position and
  retains subsequent road bends. It never draws a direct shortcut to the pin.
- Google attribution, walking/cycling notices and returned route warnings are
  displayed with guidance. Routing errors are visible and do not silently
  change providers or modes. Previously fetched live routes may remain visible
  with an update error while the user has no connection.

## Validation and field check

Run `flutter analyze`, `flutter test`, and PHPUnit `--filter GoogleRoutesTest`.
The backend tests fake Google, require authentication, check the actual request
mode, validate coordinates, exercise rate limits and upstream failures, and
ensure that no old-provider/straight-line fallback is returned.

After deployment, verify anonymous requests return 401 and authenticated route
requests return `provider: google` and the requested travel mode. Walk the
McArthur Landing Park route with the release APK. Test approaching a nearer
entrance, route refresh while on the old line, backtracking, loss of GPS/network,
and destination arrival. Automated tests cannot establish whether the provider
has mapped the particular pedestrian entrance shown in the user's photo.

At the initial configuration check, the existing Maps key returned
`403 PERMISSION_DENIED / ACCESS_DENIED` for `routes.googleapis.com`. Google
Routes access must be verified after the dedicated server key is configured.
