# DaanAR — Railway Deployment Guide

> Follow this guide when you're ready to take DaanAR from local development to live production on Railway.app.

---

## Prerequisites
- [ ] GitHub account with `daanar-api` pushed to a repository
- [ ] Railway.app free account (railway.app)
- [ ] Your Railway domain name (e.g. `daanar-api.up.railway.app`)

---

## Step 1 — Push daanar-api to GitHub

```powershell
cd "c:\Users\Harvinjee\new daanAr\daanar-api"
git init                          # if not already a git repo
git add .
git commit -m "feat: prepare for Railway deployment"
git remote add origin https://github.com/YOUR_USERNAME/daanar-api.git
git push -u origin main
```

> ⚠️ Make sure `.env` is in `.gitignore` — **never push your real `.env` to GitHub**.

---

## Step 2 — Create Railway Project

1. Go to [railway.app](https://railway.app) → **New Project**
2. Choose **Deploy from GitHub repo** → select `daanar-api`
3. Railway auto-detects PHP and deploys automatically

---

## Step 3 — Add MySQL Database

1. In your Railway project → **+ New** → **Database** → **MySQL**
2. Railway creates a MySQL instance and provides auto-variables:
   - `${{MySQL.MYSQL_HOST}}`
   - `${{MySQL.MYSQL_PORT}}`
   - `${{MySQL.MYSQL_DATABASE}}`
   - `${{MySQL.MYSQL_USER}}`
   - `${{MySQL.MYSQL_PASSWORD}}`

---

## Step 4 — Set Environment Variables

In Railway → your Laravel service → **Variables** tab, add these:

```
APP_NAME=DaanAR
APP_ENV=production
APP_KEY=<run: php artisan key:generate --show>
APP_DEBUG=false
APP_URL=https://YOUR-APP.up.railway.app

LOG_CHANNEL=stderr
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=${{MySQL.MYSQL_HOST}}
DB_PORT=${{MySQL.MYSQL_PORT}}
DB_DATABASE=${{MySQL.MYSQL_DATABASE}}
DB_USERNAME=${{MySQL.MYSQL_USER}}
DB_PASSWORD=${{MySQL.MYSQL_PASSWORD}}

SESSION_DRIVER=cookie
FILESYSTEM_DISK=public
QUEUE_CONNECTION=sync
CACHE_STORE=array

SANCTUM_STATEFUL_DOMAINS=YOUR-APP.up.railway.app
SESSION_DOMAIN=.railway.app
```

---

## Step 5 — Set Deploy Commands in Railway

In Railway → your Laravel service → **Settings** → **Deploy**:

**Build Command:**
```bash
composer install --no-dev --optimize-autoloader && php artisan config:cache && php artisan route:cache && php artisan view:cache
```

**Start Command (leave as default or set):**
```bash
vendor/bin/heroku-php-apache2 public/
```

---

## Step 6 — Run Database Migrations

In Railway → your Laravel service → **Shell** tab, run:

```bash
php artisan migrate --force
php artisan db:seed --force
php artisan storage:link
```

---

## Step 7 — Update Flutter App Base URL

In `daanar_app/lib/core/constants.dart`:
```dart
static const String baseUrl = 'https://YOUR-APP.up.railway.app/api/v1';
```

Then rebuild the APK:
```powershell
cd "c:\Users\Harvinjee\new daanAr\daanar_app"
flutter build apk --release
```

---

## Step 8 — Update CORS for Production

In `daanar-api/config/cors.php`, update `allowed_origins`:
```php
'allowed_origins' => [
    'https://YOUR-APP.up.railway.app',
    'http://localhost',
],
```

Then commit and push — Railway auto-redeploys.

---

## Post-Deployment Checklist

- [ ] `https://YOUR-APP.up.railway.app/` loads landing page
- [ ] `https://YOUR-APP.up.railway.app/admin` loads Filament admin
- [ ] `https://YOUR-APP.up.railway.app/api/v1/landmarks` returns JSON
- [ ] `https://YOUR-APP.up.railway.app/api/v1/municipalities` returns JSON
- [ ] Flutter app connects to Railway URL and loads landmarks
- [ ] Admin creates a landmark — appears in app within seconds

---

## Build Commands Reference

```powershell
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for distribution)
flutter build apk --release
# Output: build\app\outputs\flutter-apk\app-release.apk

# App Bundle (for Play Store)
flutter build appbundle --release
# Output: build\app\outputs\bundle\release\app-release.aab
```
