# DaanAR — End-to-End Test Checklist

> Use this file to manually verify the entire system works before deployment or release.
> Check off each item as you confirm it passes.

---

## 🖥️ Backend & Admin

- [ ] **1.** Open `http://127.0.0.1:8000/admin` → redirects to login page
- [ ] **2.** Log in with `admin@daanar.ph` / `password` → admin dashboard appears
- [ ] **3.** Create a new Landmark with: name, description, category, municipality, lat/lng, cover image
- [ ] **4.** Confirm landmark appears at `GET /api/v1/landmarks` (check JSON response)
- [ ] **5.** Mark landmark as featured → appears at `GET /api/v1/landmarks/featured`
- [ ] **6.** Confirm `GET /api/v1/municipalities` returns all municipalities

---

## 🌐 Landing Page

- [ ] **7.** Open `http://127.0.0.1:8000/` → landing page loads (not a redirect)
- [ ] **8.** "Featured Landmarks" section shows real landmark cards with images
- [ ] **9.** Municipality section shows all municipalities with landmark counts
- [ ] **10.** Page renders correctly on a mobile viewport (DevTools → toggle device toolbar)
- [ ] **11.** Landmark hero images load (not broken `[img]` icons)

---

## 📱 Flutter App — Map

- [ ] **12.** Open the Flutter app on device
- [ ] **13.** Go to **Map** tab → tap "My Location" → GPS blue dot appears
- [ ] **14.** New landmark appears as a map pin at correct coordinates
- [ ] **15.** Tap landmark pin → bottom sheet appears with correct name and description
- [ ] **16.** Municipality filter works — shows only landmarks in selected municipality

---

## 🧭 Flutter App — Navigation

- [ ] **17.** Tap "Navigate" on a landmark → route line drawn on map
- [ ] **18.** "Recenter" button appears when map is scrolled away
- [ ] **19.** Walk/simulate off route → app reroutes automatically within ~5 seconds
- [ ] **20.** Within 50m of destination → golden "You're almost there!" banner appears
- [ ] **21.** Tap "View AR" on banner → AR page opens in browser/WebView

---

## 📷 AR Feature

- [ ] **22.** AR page loads in Chrome/WebView (no blank screen or spinner stuck)
- [ ] **23.** Camera permission prompt appears and is grantable
- [ ] **24.** Camera feed is visible on the AR page
- [ ] **25.** 3D model appears and can be rotated/pinched/zoomed
- [ ] **26.** "View in Your Space" (markerless AR) button works on device

---

## ⚠️ Error States

- [ ] **27.** Open AR on a landmark with **no 3D model** → page handles gracefully (no crash)
- [ ] **28.** Turn off PHP server → Flutter app shows "Offline mode — showing cached data"
- [ ] **29.** Open admin panel at Railway production URL → loads and functions correctly

---

## 🚀 Post-Deployment (Railway)

- [ ] **30.** `APP_URL` is set to Railway domain in Railway Variables tab
- [ ] **31.** `php artisan migrate --force` ran successfully on Railway
- [ ] **32.** `php artisan storage:link` ran on Railway (or nixpacks.toml build handled it)
- [ ] **33.** Upload a GLB file via admin → file saves and AR page loads the model
- [ ] **34.** Access admin panel from a different device (phone/other PC) → works correctly

---

> **Tip:** Run this checklist before every major release or deployment.
