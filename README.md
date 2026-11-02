# DaanAR

Augmented reality navigation and heritage guide for historical landmarks in Pangasinan, Philippines.

## Project Structure

- `daanar-api/` - Laravel 11 REST API and Filament admin panel for managing landmarks, 3D models, municipalities, trails, and visit analytics.
- `daanar_app/` - Flutter mobile application with offline caching, interactive trail navigation, and native ARCore 3D landmark viewing.

## Main Features

1. **3D Studio & ARCore Viewer** - Inspect 3D heritage models offline or place them in real-world space on supported Android devices.
2. **Map & Heritage Trails** - Browse landmarks by municipality and follow multi-stop routes with live GPS distance tracking.
3. **Offline Mode** - Caches landmark records, trails, and bundled 3D assets locally so the guide remains usable without mobile data.
4. **Admin Panel** - Filament dashboard for updating site records, uploading `.glb` models, and viewing visit reports.

## Tech Stack

- **Mobile:** Flutter (Dart), Riverpod, Google Maps, ARCore / SceneView (Android)
- **Backend:** PHP 8.4, Laravel 11, Filament 3, MySQL
