# DaanAR 
**An Augmented Reality Navigation System for Historical Landmarks in Pangasinan**

DaanAR is a specialized mobile augmented reality (AR) navigation and heritage discovery system tailored for historical landmarks across Pangasinan, Philippines. It integrates live location services, curated heritage trails, an AR camera view, and offline data caching.

---

## System Architecture

```
new daanAr/
├── daanar-api/          # Laravel 11 Backend & Admin CMS
│   ├── app/             # API Controllers, Models, Middleware
│   ├── database/        # Migrations & Seeders (Landmarks, Municipalities, Trails)
│   ├── routes/          # RESTful API endpoints & Web routes
│   └── resources/views/ # Blade-based Administrative Dashboard
│
└── daanar_app/          # Flutter Cross-Platform Mobile Application
    ├── lib/             # Presentation, Riverpod Providers, Core Services
    │   ├── core/        # Theme, API Client, Persistent Cache Service
    │   ├── models/      # Data Models (Landmark, Trail, Municipality)
    │   ├── screens/     # AR View, Map, Trails, Details, Splash
    │   └── widgets/     # Reusable UI components & Offline Banners
    └── assets/          # Static branding, logo, and offline icons
```

---

## Key Features

1. **Augmented Reality Navigation**: Overlay directional waypoints and historical annotations onto real-world camera feeds.
2. **Interactive Map & Heritage Trails**: Explore curated walking and cultural routes with distance calculation and interactive pins.
3. **Offline Caching Engine**: Automatic persistent cache of landmarks, trails, and municipalities using SharedPreferences.
4. **Administrative CMS**: Comprehensive web portal for managing landmarks, AR coordinate anchors, and trail routes.
5. **REST API**: Secure token authentication, categorized landmark discovery, and spatial querying.

---

## Tech Stack

* **Mobile App**: Flutter (Dart), Flutter Riverpod, Google Maps Flutter, Shared Preferences
* **Backend API**: PHP 8.2+, Laravel 11, MySQL / MariaDB
* **Version Control**: Git & GitHub
