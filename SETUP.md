# DaanAR — Developer Startup Guide

## Prerequisites (one-time setup)

| Tool | Version | Download |
|------|---------|----------|
| Flutter | 3.x+ | https://flutter.dev |
| PHP | 8.1+ | https://www.php.net |
| Composer | latest | https://getcomposer.org |
| ngrok | latest | https://ngrok.com (optional — only needed for external access) |
| Android Studio | latest | https://developer.android.com/studio |

---

## Project Structure

```
new daanAr/
├── daanar-api/          ← Laravel REST API (backend)
├── daanar_app/          ← Flutter mobile app (frontend)
└── start-ngrok.ps1      ← Dev script (starts PHP server + ngrok + updates URL)
```

---

## Option A — Local WiFi (Phone + PC on same network)

This is the fastest way. No ngrok needed.

### Step 1 — Start the Laravel API

Open **PowerShell** and run:

```powershell
cd "c:\Users\Harvinjee\new daanAr\daanar-api"
php -S 0.0.0.0:8000 vendor\laravel\framework\src\Illuminate\Foundation\resources\server.php
```

Leave this window open. The API is now running.

### Step 2 — Find your PC's local IP

In a new PowerShell window:

```powershell
ipconfig
```

Look for **IPv4 Address** under your WiFi adapter (e.g. `192.168.0.32`).

### Step 3 — Set the base URL in the app

Open `daanar_app/lib/core/constants.dart` and set:

```dart
static const String baseUrl = 'http://YOUR_PC_IP:8000/api/v1';
// Example: 'http://192.168.0.32:8000/api/v1'
```

### Step 4 — Set your ORS API key

In the same file `constants.dart`:

```dart
static const String orsApiKey = 'YOUR_ORS_API_KEY';
```

> Get a free key at https://openrouteservice.org/dev/#/signup (no credit card needed)

### Step 5 — Build and install the APK

```powershell
cd "c:\Users\Harvinjee\new daanAr\daanar_app"
flutter build apk --debug
```

Then install `build\app\outputs\flutter-apk\app-debug.apk` on your phone.
Make sure your phone is connected to the **same WiFi network** as your PC.

---

## Option B — ngrok (Phone on any network)

Use this if the phone is not on the same WiFi as your PC.

### Step 1 — Run the startup script

```powershell
cd "c:\Users\Harvinjee\new daanAr"
.\start-ngrok.ps1
```

This script automatically:
1. Starts the PHP/Laravel server on port 8000
2. Starts an ngrok tunnel
3. Updates `constants.dart` with the live ngrok URL

### Step 2 — Set your ORS API key

Open `daanar_app/lib/core/constants.dart` and paste your ORS key:

```dart
static const String orsApiKey = 'YOUR_ORS_API_KEY';
```

### Step 3 — Build and install the APK

```powershell
cd "c:\Users\Harvinjee\new daanAr\daanar_app"
flutter build apk --debug
```

Install `build\app\outputs\flutter-apk\app-debug.apk` on your phone.

> Each time you restart ngrok, the URL changes. Re-run start-ngrok.ps1 and rebuild.

---

## Using the App

### Navigation Feature

1. Open the **Map** tab
2. Tap the **My Location** button — grant location permission when asked
3. Tap any **landmark marker** on the map
4. In the bottom sheet, tap **Navigate**
5. A route line is drawn to your destination

| While navigating | What to do |
|-----------------|-----------|
| Camera drifts away | Tap the **Recenter** button (appears when you scroll the map) |
| Walked off route | App **automatically reroutes** within seconds |
| Within 50m of destination | Golden **"You're almost there!"** banner appears |
| Ready for AR | Tap **View AR** on the banner to launch Augmented Reality |
| Done | Tap the red **Stop Navigation** button |

### AR Feature (Augmented Reality)

- AR is triggered automatically when you are within **50 metres** of a destination during navigation
- You can also launch AR from any landmark's **Detail** screen via the "View in AR" button
- AR opens in **Chrome** — allow camera permission when prompted

---

## Secrets — Do NOT commit these to GitHub

| File | Secret | How to handle |
|------|--------|---------------|
| `constants.dart` | `orsApiKey` | Keep as placeholder in git, paste real key locally after each checkout |
| `constants.dart` | `baseUrl` | Keep as local IP or placeholder in git |

---

## Troubleshooting

### "Offline mode — showing cached data"
1. Is the PHP server running? (Step 1 above)
2. Is `baseUrl` in `constants.dart` set to your current PC IP?
3. Are phone and PC on the same WiFi?
4. Did you rebuild the APK after changing the URL?

### "Could not calculate route"
- Check your ORS API key is set in `constants.dart`
- ORS free tier: 2,000 requests/day — resets at midnight UTC

### Location permission denied
- Phone: **Settings > Apps > DaanAR > Permissions > Location > Allow all the time**

### Blue dot not moving during navigation
- GPS is weak indoors — go outside for accurate tracking
- Minimum movement to trigger update: ~5 metres

---

## Git Branches

| Branch | Purpose |
|--------|---------|
| `main` | Stable, production-ready code |
| `feature/navigation` | Active navigation development (current branch) |

```powershell
# Push current work
git push origin feature/navigation

# Merge into main when ready
git checkout main
git merge feature/navigation
git push origin main
```
