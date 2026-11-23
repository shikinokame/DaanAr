# Native walking AR field test

The existing Map and Trail **AR guide** buttons now open `ArWalkingNavigationActivity`
inside DaanAR. Flutter gets a fresh authenticated Google WALK route before launch
and handles subsequent routing requests; Android owns the camera, GPS and ARCore
session. Driving or untyped cached geometry is never used as a
walking path. No additional API key or Geospatial/VPS service is required.

## First outdoor test

1. Install the new APK over the previous DaanAR installation. Sign in online.
2. Choose a nearby landmark and Walking navigation. Start with a flat, safe,
   unobstructed 30–60 m section, preferably with one corner.
3. Open AR guide, allow camera and precise location permissions, and stand still.
4. Wait for a fresh GPS fix (at most 10 seconds old, accuracy at most 12 m).
   Point the camera down and scan the walkway. Walking AR uses ARCore Depth
   when available and limits ground-only placement to nearby arrows.
5. Tap **Align to path**. While stationary, tap a point on the walkway near your
   feet, then tap farther ahead on the same straight section in the direction of
   travel. Pick the second point 1.5–7 m ahead of the first. After alignment,
   point the camera ahead and slightly down to see the arrows.
6. Walk past a few arrows. They should grow with perspective and pass out of view,
   with sustained visual progress retiring old markers. Stop and look sideways,
   behind, and back: existing markers should keep their physical positions.
7. Scan the approach to a corner, fence or wall. Markers should disappear where
   the ground cannot be confirmed or an obstruction is detected. Check that an arrow before the corner
   follows the current segment. Realign on the next straight section if needed.
8. A gold marker may appear near the route endpoint on visible ground. **Mark arrived** is offered
   only when both GPS and visual route progress are near the endpoint.
9. Test Back to map, reopening AR, background/resume, camera/precise GPS denial,
   GPS off/on, weak GPS, temporarily covering the camera, and internet loss during
   rerouting. The UI must remain usable and uncertain arrows must be hidden.

## Implementation limits and behavior

- Alignment combines GPS route progress with two points chosen on the visible
  path. Ground and depth measurements cannot determine whether a surface is a
  public walkway. Follow the real walkway and verify ambiguous sections on the map.
- The alignment transform is frozen after explicit calibration. Camera motion
  (visual odometry), not per-fix GPS jumps, drives marker passage. Each marker has
  its own local ARCore anchor. A reference anchor accounts for world refinements.
- Reusable arrow meshes are spaced 5 m apart and shown up to 10 m ahead. Placements
  require a tracked ground footprint and reject detected obstructions. Beyond
  5.5 m from the camera they also require a depth sample. With missing or
  unsupported depth, obstacles that ARCore has not detected can still overlap
  nearby arrows.
  Anchors are detached when recycled. Old arrows require 1.5 m of passage,
  deviation at most 3 m, and 700 ms sustained progress before retirement.
- Camera tracking loss hides arrows immediately. More than 3 seconds of loss,
  app backgrounding, route replacement, excessive GPS/AR discrepancy, or walking
  60 m from alignment requires explicit realignment. No automatic snapping occurs.
- Slopes, stairs and changes in ground level can hide markers until realignment.
- Rerouting ignores GPS accuracy worse than 40 m, permits at most one pending
  request, and waits at least 15 seconds between attempts. It refreshes off-route,
  after 10 m movement within 150 m of arrival, or after 60 s plus 25 m movement.
  While aligning or aligned, only off-route movement triggers a refresh.
  A successful route replacement asks the user to stop and align again.
- Provider warnings and Google Maps attribution remain visible. No coordinates,
  route polylines, keys or camera frames are added to logs or persisted here.
- Route payloads stay in process memory rather than Android intent extras. After
  process death, return to the map and start a fresh navigation session.

## Automated verification

- Flutter analyzer and regression tests, including walking-only codec/order checks.
- Android `:app:testDebugUnitTest --tests ph.daanar.daanar_app.WalkingRouteGeometryTest`:
  spacing, road corners, backtracking, geographic/world transforms, GPS-jitter
  passage hysteresis, off-route non-consumption, bounds and invalid inputs.
- Release APK build and Android signature/version verification.

## 1.0.4 teardown correction

The POCO crash report showed `libfilament-jni.so` / `TransformManager.getInstance`
called from geometry destruction inside `ArWalkingNavigationActivity.onDestroy`.
The previous code could reach that cleanup after SceneView's lifecycle observer
had already destroyed its engine. Native use-after-free cannot be caught with a
Kotlin `try/catch`.

The navigation scene now uses its own explicitly advanced lifecycle, and an owned
SceneView closes anchors and meshes before its ARCore session and Filament engine.
Lifecycle destruction, window detach, and Activity destruction share a one-shot
teardown guard. Late render/reroute callbacks are rejected once teardown starts.
Four regression tests check cleanup order, repeated destruction, reentrant detach,
and failure cleanup. Device verification still needs repeated open/back, home/resume,
permission denial, and re-opening after exiting the AR screen.

The phone tests above remain required before calling alignment verified.
