# Turn by turn navigation validation

Release 1.0.1 build 2, evaluated on 13 November 2026.

## Implemented behavior

- Shared maneuver arrows and distance-to-turn banners on the map, trail map,
  and walking camera guide.
- Road-segment projection for remaining distance and step progression, including
  OpenRouteService waypoint indices and OSRM maneuver locations.
- Upcoming instruction preview, estimated travel time, off-route display and
  reroute attempts with a cooldown.
- Gold camera chevrons based on the road look-ahead point and compass heading.
  These are approximate screen overlays, not surveyed or world-anchored paths.
- Camera arrows are hidden when GPS accuracy is poor, the compass is unavailable,
  the route is too far away, or the phone is pointed away from the route.
- AR walking mode is accessible from walking navigation. Other modes retain
  map-based turn guidance.

## Completed checks

- Flutter analysis: no issues.
- Flutter tests: 19 passed. Coverage includes provider response parsing, turn
  progression, arrival, backtracking, loop continuity, sparse route geometry,
  cached steps, off-route state, missing guidance and enlarged-text layout.
- Backend PHPUnit: 7 tests and 16 assertions passed with PHP 8.4.27. Coverage
  includes public landmark/municipality/trail reads, landmark detail and AR page
  rendering, missing model files and the CMS login redirect.
- AR frontend Node tests: 5 passed, including model URL validation and error UI.
- Live Railway health, landmark list and trail list returned HTTP 200.
- Live OpenRouteService walking smoke request returned HTTP 200 with one route
  and three instructions.

The backend suite ran against an isolated MariaDB instance on port 3307 using
the previously exported local backup. No migration, seed, or production database
write was part of the test run. The installed PHP/XAMPP configuration was not
replaced. The original local XAMPP database failed to start with an InnoDB
assertion; repair of that database is a separate task.

## Tests still required on a physical phone

No Android phone was connected during this run. Automated tests do not establish
that every system feature works in every environment. Before distributing the
APK broadly, verify:

1. Install the signed release over the current app and confirm login and maps.
2. Follow a short known walking route with a left turn and a right turn. Confirm
   the arrow, turn distance and following instruction change after each turn.
3. Deliberately leave the route at a safe pedestrian location and confirm the
   rerouting state, refreshed path and retry behavior on a weak connection.
4. Enter the camera guide, rotate the phone, background/resume the app, and
   confirm camera recovery and compass calibration.
5. Disable location or camera access and verify the fallback guidance. Retry
   after restoring permission.
6. Check a heritage trail with multiple stops, offline cached content, field
   history and the installed app's account-specific behavior.

Voice guidance is not included in this release. GPS/compass accuracy, provider
availability, road-data quality and network conditions affect the guidance.
The previously identified admin API/audit-trail security gaps are outside this
navigation change; these tests are not a security certification.
