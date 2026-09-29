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

### 3. Case-Sensitivity in PHP CLI Flags (`-s` vs `-S`)
- **The Error**: `Could not open input file: 0.0.0.0:8000`
- **Cause**: PHP CLI switches are case-sensitive. `-s` (lowercase) tries to output syntax-highlighted source code, whereas `-S` (uppercase) starts the built-in web server.

### 4. Unquoted File Paths with Spaces in PowerShell
- **The Error**: `Set-Location : A positional parameter cannot be found that accepts argument 'daanAr...'`
- **Cause**: The folder name `new daanAr` contains a space. PowerShell interprets spaces as parameter separators unless the path is enclosed in quotes `"` or `'`.

---

## 🛠️ Task 2: How to Solve and Never Experience It Again

### Solution 1: Recommended Way to Start the Server
Always run `php artisan serve` from inside the `daanar-api` directory. Artisan automatically handles the `public` directory and routing for you.

```powershell
# 1. Navigate into the API directory (always use quotes around paths with spaces)
cd "c:\Users\Harvinjee\new daanAr\daanar-api"

# 2. Start the server
php artisan serve --port 8000
```
*To allow mobile phones on the same WiFi to connect, specify `--host 0.0.0.0`:*
```powershell
php artisan serve --host 0.0.0.0 --port 8000
```

---

### Solution 2: How to Clear Port 8000 (When Port is Blocked)
If you see `Failed to listen on 0.0.0.0:8000`, run this single command in PowerShell to kill all leftover PHP background processes:

```powershell
Stop-Process -Name php -Force -ErrorAction SilentlyContinue
```
Then start `php artisan serve --port 8000` again.

---

### Solution 3: If Using `php -S` Directly
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
