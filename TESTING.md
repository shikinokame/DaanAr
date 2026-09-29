# DaanAR — End-to-End Test Checklist
> Run through this checklist **before every release** to ensure all features work correctly.
> Tick each box manually as you test. A ✅ means PASS, ❌ means FAIL (document the error).

---

## Environment Setup
- [ ] PHP server is running (`php artisan serve` or `php -S` from `public/`)
- [ ] Database is running (XAMPP MySQL or Railway MySQL)
- [ ] `constants.dart` `baseUrl` points to the correct server
- [ ] Flutter app is installed on the test device

---

## Part 1 — Admin Panel & Backend

| # | Test | Expected | Status |
|:--|:-----|:---------|:-------|
| 1 | Open `http://127.0.0.1:8000/admin` in browser | Filament login page loads | |
| 2 | Log in with `admin@daanar.ph` / `password` | Dashboard appears, no errors | |
| 3 | Go to Landmarks → Create New Landmark | Form loads with all fields | |
| 4 | Fill form: Name, Description, Category, Municipality, Lat/Lng, upload image | Landmark saves successfully | |
| 5 | Mark the new landmark as `is_featured = true` | Toggle saves | |
| 6 | GET `http://127.0.0.1:8000/api/v1/landmarks` in browser/Postman | JSON response with paginated landmarks | |
| 7 | GET `http://127.0.0.1:8000/api/v1/landmarks/featured` | New featured landmark appears | |
| 8 | GET `http://127.0.0.1:8000/api/v1/municipalities` | All 5 municipalities with landmark counts | |
| 9 | GET `http://127.0.0.1:8000/api/v1/landmarks?category=church` | Only church landmarks returned | |
| 10 | GET `http://127.0.0.1:8000/api/v1/landmarks?municipality=dagupan` | Only Dagupan landmarks returned | |

---

## Part 2 — Landing Page

| # | Test | Expected | Status |
|:--|:-----|:---------|:-------|
| 11 | Open `http://127.0.0.1:8000/` in browser | Landing page loads (NOT admin redirect) | |
| 12 | "Featured Landmarks" section | Shows real landmarks from DB | |
| 13 | New featured landmark (created in test #5) | Appears on landing page | |
| 14 | Municipalities section | Shows all municipalities with landmark counts | |
| 15 | Mobile viewport (resize browser to 375px width) | Layout is responsive, no overflow | |

---

## Part 3 — Flutter App: Map & Landmarks

| # | Test | Expected | Status |
|:--|:-----|:---------|:-------|
| 16 | Open Flutter app → Map tab | Map loads, no API error toast | |
| 17 | Tap "My Location" button | GPS blue dot appears on map | |
| 18 | Landmark pins visible on map | All landmarks show as pins at correct coords | |
| 19 | New landmark (created in test #4) | Appears as pin at entered lat/lng | |
| 20 | Tap any landmark pin | Bottom sheet slides up with correct data | |
| 21 | Municipality filter → select "Dagupan City" | Only Dagupan landmarks visible on map | |

---

## Part 4 — Flutter App: Navigation

| # | Test | Expected | Status |
|:--|:-----|:---------|:-------|
| 22 | Tap "Navigate" on a landmark | Blue route line drawn from current location | |
| 23 | Scroll the map away | Floating "Recenter" button appears | |
| 24 | Tap "Recenter" | Map snaps back to current location | |
| 25 | Walk / simulate movement off the route | App reroutes automatically (route line redraws) | |
| 26 | Arrive within 50m of destination | Gold "You're almost there!" banner appears | |
| 27 | Tap red "Stop Navigation" button | Route line disappears, normal map mode restored | |

---

## Part 5 — AR Feature

| # | Test | Expected | Status |
|:--|:-----|:---------|:-------|
| 28 | Tap "View in AR" on a landmark detail screen | AR page opens in browser / WebView | |
| 29 | Tap "View AR" on the "almost there" banner during navigation | Same AR page opens | |
| 30 | Camera permission prompt appears | Prompt shown on first launch | |
| 31 | Grant camera permission | Camera feed visible on screen | |
| 32 | Point camera at HIRO/landmark marker | 3D model or building stand-in appears | |
| 33 | Landmark info panel visible | Name, category, short description shown at bottom | |
| 34 | Open `http://127.0.0.1:8000/ar/test` on device browser | Test AR page loads, camera works | |

---

## Part 6 — Error States

| # | Test | Expected | Status |
|:--|:-----|:---------|:-------|
| 35 | Stop PHP server, reload app | "Offline mode — showing cached data" message | |
| 36 | Set invalid ORS API key in constants.dart, tap Navigate | "Could not calculate route" error shown | |
| 37 | Open landmark with no AR model in demo mode | Generic 3D building renders (no crash) | |
| 38 | No GPS signal (airplane mode) | Location error handled gracefully (no crash) | |
| 39 | Open `/api/v1/landmarks/9999` (nonexistent) | 404 JSON response, not a server crash | |

---

## Sign-Off

| Tester | Date | Version | Result |
|:-------|:-----|:--------|:-------|
| | | 1.0.0 | PASS / FAIL |

**Notes / Bugs Found:**
```
(write any issues here)
```
