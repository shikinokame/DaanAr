# DaanAR — PHP Server Troubleshooting & Solution Guide

This guide explains **why** errors like `Failed to listen on 0.0.0.0:8000` or `Failed opening required index.php` occur when starting the Laravel server, and **how to solve and prevent them**.

---

## 🔍 Task 1: Why Does This Keep Happening? (Main Causes)

### 1. Zombie PHP Processes Locking Port 8000
- **The Error**: `Failed to listen on 0.0.0.0:8000 (reason: ?)` or `Failed to listen on 127.0.0.1:8000`
- **Cause**: When you close your terminal or a previous server command crashes/stops unexpectedly, the underlying `php.exe` process often stays alive in the background holding onto TCP Port 8000. Windows won't allow a new process to bind to port 8000 while another process is using it.

### 2. Incorrect Working Directory (`cwd`) for `php -S`
- **The Error**: `PHP Fatal error: Uncaught Error: Failed opening required '.../daanar-api/index.php'`
- **Cause**: In Laravel, `index.php` is located inside `daanar-api/public/index.php`. When running `php -S 0.0.0.0:8000 vendor/.../server.php` from the `daanar-api` root folder without specifying `-t public`, PHP looks for `daanar-api/index.php` (which does not exist).

### 3. Missing MariaDB / MySQL Background Service
- **The Error**: `SQLSTATE[HY000] [2002] No connection could be made because the target machine actively refused it`
- **Cause**: MariaDB/MySQL (`mysqld.exe`) was not running. Laravel requires the database to serve landmark data and authenticate users.

### 4. Multiple PHP Installations on Machine (XAMPP vs Herd)
- **The Error**: `Class "Pdo\Mysql" not found`
- **Cause**: System `PATH` was invoking XAMPP's PHP 8.2 CLI which did not have `pdo_mysql` enabled, instead of Laravel Herd's PHP 8.4 (`%USERPROFILE%\.config\herd-lite\bin\php.exe`).

### 5. Unquoted File Paths with Spaces in PowerShell
- **The Error**: `Set-Location : A positional parameter cannot be found that accepts argument 'daanAr...'`
- **Cause**: The folder name `new daanAr` contains a space. PowerShell interprets spaces as parameter separators unless the path is enclosed in quotes `"` or `'`.

---

## 🛠️ Task 2: How to Solve It — 1-Click Solution

### Solution 1: Use `START_SERVER.bat` (Recommended — 100% Automated)
Simply **double-click** `START_SERVER.bat` in the project root folder `c:\Users\Harvinjee\new daanAr`.

It automatically:
1. Starts **MariaDB/MySQL** if it's stopped.
2. Cleans up any leftover processes holding port 8000.
3. Automatically launches PHP using Herd's full **PHP 8.4 engine** (with both `intl` and `pdo_mysql` enabled).
4. Connects the **ngrok tunnel** (`letdown-twiddle-thirty.ngrok-free.dev`).
5. Updates `constants.dart` in Flutter with the live ngrok URL.
6. Displays a live dashboard with all URLs and credentials.
7. Shuts down everything cleanly when you press **`Q`** or close the window.

---

### Solution 2: Clean Stop (`STOP_SERVER.bat`)
If you ever want to forcefully stop all background PHP servers or ngrok tunnels, just double-click **`STOP_SERVER.bat`**.

---

### Solution 3: Manual Startup in Terminal
If you want to use `php -S` without Artisan, you **must** change your working directory into `daanar-api\public`:

```powershell
cd "c:\Users\Harvinjee\new daanAr\daanar-api\public"
php -S 0.0.0.0:8000 ..\vendor\laravel\framework\src\Illuminate\Foundation\resources\server.php
```

---

### Solution 4: Use the Automated Startup Script (`start-ngrok.ps1`)
We have updated `start-ngrok.ps1` in the project root folder. It automatically:
1. Kills any zombie PHP processes holding port 8000.
2. Starts the PHP server with the correct `-t public` directory.
3. Launches ngrok and updates `constants.dart` automatically.

To run it:
```powershell
cd "c:\Users\Harvinjee\new daanAr"
.\start-ngrok.ps1
```

---

## 💡 Quick Summary Checklist

| Issue | Quick Fix |
| :--- | :--- |
| **Port 8000 in use** | Run `Stop-Process -Name php -Force` |
| **Missing `index.php` error** | Use `php artisan serve` OR `cd daanar-api\public` |
| **Path error in PowerShell** | Put quotes around path: `"c:\Users\Harvinjee\new daanAr\daanar-api"` |
| **Command typo** | Use uppercase `-S` (not `-s`) |
