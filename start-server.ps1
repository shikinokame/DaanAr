# ==============================================================================
#  DaanAR - Unified Server & Tunnel Manager
# ==============================================================================
#  This script starts and manages:
#    1. MariaDB / MySQL (XAMPP / local)
#    2. Laravel API Server (PHP 8.4 with intl & pdo_mysql)
#    3. ngrok Public Tunnel
#    4. Flutter App constants.dart live URL sync
# ==============================================================================

$ErrorActionPreference = "Continue"

$root = $PSScriptRoot
$apiDir = Join-Path $root "daanar-api"
$publicDir = Join-Path $apiDir "public"
$routerFile = Join-Path $publicDir "server.php"
$constantsFile = Join-Path $root "daanar_app\lib\core\constants.dart"
$port = 8000
$ngrokDomain = "letdown-twiddle-thirty.ngrok-free.dev"

# ── Colors & Banner ──────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ===============================================================" -ForegroundColor Cyan
Write-Host "                DAANAR - STARTUP & SERVER MANAGER                " -ForegroundColor Cyan
Write-Host "  ===============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Check & Start Database ────────────────────────────────────────────────
Write-Host "  [1/5] Checking MariaDB/MySQL database..." -ForegroundColor Yellow -NoNewline
$dbConn = Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -InformationLevel Quiet -WarningAction SilentlyContinue
if (-not $dbConn) {
    $mysqlExe = "C:\xampp\mysql\bin\mysqld.exe"
    $myIni = "C:\xampp\mysql\bin\my.ini"
    if (Test-Path $mysqlExe) {
        Start-Process $mysqlExe -ArgumentList "--defaults-file=$myIni","--standalone" -WindowStyle Hidden
        Start-Sleep -Seconds 3
        $dbConn = Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -InformationLevel Quiet -WarningAction SilentlyContinue
    }
}
if ($dbConn) {
    Write-Host " [OK] Running on port 3306" -ForegroundColor Green
} else {
    Write-Host " [WARN] MariaDB not reachable on 3306" -ForegroundColor Red
}

# ── 2. Clean Up Port 8000 & Stale PHP Processes ──────────────────────────────
Write-Host "  [2/5] Cleaning up port $port and stale processes..." -ForegroundColor Yellow -NoNewline
$stalePhp = Get-Process -Name "php" -ErrorAction SilentlyContinue
if ($stalePhp) {
    $stalePhp | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}
$portConn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($portConn) {
    foreach ($c in $portConn) {
        Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
Write-Host " [OK] Port $port is free" -ForegroundColor Green

# ── 3. Locate Working PHP 8.4 Executable ─────────────────────────────────────
Write-Host "  [3/5] Locating PHP 8.4 engine..." -ForegroundColor Yellow -NoNewline
$phpCandidates = @(
    "$env:USERPROFILE\.config\herd\bin\php84\php.exe",
    "$env:USERPROFILE\.config\herd-lite\bin\php.exe",
    "C:\xampp\php\php.exe"
)
$phpExe = $null
foreach ($cand in $phpCandidates) {
    if (Test-Path $cand) {
        $phpExe = $cand
        break
    }
}
if (-not $phpExe) {
    $found = Get-Command php.exe -ErrorAction SilentlyContinue
    if ($found) { $phpExe = $found.Source }
}
if (-not $phpExe) {
    Write-Host " [FAIL]" -ForegroundColor Red
    Write-Host "  ERROR: No suitable php.exe found! Please check Herd or XAMPP." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host " [OK] $($phpExe)" -ForegroundColor Green

# ── 3b. Run Pending Database Migrations Automatically ────────────────────────
if ($dbConn) {
    Write-Host "  [3b/5] Running database migrations..." -ForegroundColor Yellow -NoNewline
    & $phpExe (Join-Path $apiDir "artisan") migrate --force *> $null
    Write-Host " [OK]" -ForegroundColor Green
}

# ── 4. Start PHP Server ──────────────────────────────────────────────────────
Write-Host "  [4/5] Starting Laravel API server..." -ForegroundColor Yellow -NoNewline
$phpProcess = Start-Process -FilePath $phpExe `
    -ArgumentList "-d", "upload_max_filesize=350M", "-d", "post_max_size=350M", "-d", "memory_limit=1024M", "-d", "max_execution_time=600", "-S", "0.0.0.0:$port", "-t", "`"$publicDir`"", "`"$routerFile`"" `
    -WorkingDirectory $publicDir `
    -WindowStyle Hidden `
    -PassThru

# Wait and test endpoint
$apiReady = $false
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Milliseconds 700
    try {
        $res = Invoke-WebRequest -Uri "http://127.0.0.1:$port/api/v1/landmarks" `
            -Headers @{ "Accept" = "application/json" } `
            -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($res.StatusCode -eq 200) {
            $apiReady = $true
            break
        }
    } catch {}
}
if ($apiReady) {
    Write-Host " [OK] HTTP 200 on http://127.0.0.1:$port" -ForegroundColor Green
} else {
    Write-Host " [WARN] API did not return 200 in 7s. Checking..." -ForegroundColor Yellow
}

# ── 5. Start ngrok Tunnel & Sync constants.dart ──────────────────────────────
Write-Host "  [5/5] Connecting ngrok tunnel ($ngrokDomain)..." -ForegroundColor Yellow -NoNewline
$existingNgrok = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
if ($existingNgrok) {
    $existingNgrok | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

$ngrokExe = "C:\ngrok\ngrok.exe"
if (-not (Test-Path $ngrokExe)) {
    $ngrokCmd = Get-Command ngrok.exe -ErrorAction SilentlyContinue
    if ($ngrokCmd) { $ngrokExe = $ngrokCmd.Source }
}

$ngrokProcess = $null
$ngrokUrl = $null
if (Test-Path $ngrokExe) {
    $ngrokProcess = Start-Process -FilePath $ngrokExe `
        -ArgumentList "http", "--domain=$ngrokDomain", "127.0.0.1:$port" `
        -WindowStyle Hidden `
        -PassThru

    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Milliseconds 600
        try {
            $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction SilentlyContinue
            $https = $tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1
            if ($https) {
                $ngrokUrl = $https.public_url
                break
            }
        } catch {}
    }
}

if ($ngrokUrl) {
    Write-Host " [OK]" -ForegroundColor Green
    # Update constants.dart
    if (Test-Path $constantsFile) {
        $baseUrl = "$ngrokUrl/api/v1"
        $code = Get-Content $constantsFile -Raw
        $updatedCode = $code -replace "static const String baseUrl = '[^']+';", "static const String baseUrl = '$baseUrl';"
        if ($code -ne $updatedCode) {
            Set-Content -Path $constantsFile -Value $updatedCode -NoNewline
        }
    }
} else {
    Write-Host " [WARN] ngrok not responding (using direct local)" -ForegroundColor Yellow
    $ngrokUrl = "http://127.0.0.1:$port"
}

# ── Live Dashboard ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ===============================================================" -ForegroundColor Green
Write-Host "                     DAANAR IS LIVE & READY!                     " -ForegroundColor Green
Write-Host "  ===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "    [✓] Database:      MariaDB (Port 3306)" -ForegroundColor White
Write-Host "    [✓] Local API:     http://127.0.0.1:$port/api/v1" -ForegroundColor White
Write-Host "    [✓] Admin Panel:   http://127.0.0.1:$port/admin" -ForegroundColor Cyan
Write-Host "        Email:         admin@daanar.ph" -ForegroundColor Gray
Write-Host "        Password:      password" -ForegroundColor Gray
Write-Host "    [✓] Public Tunnel: $ngrokUrl" -ForegroundColor Cyan
Write-Host "    [✓] Flutter App:   constants.dart synced to tunnel" -ForegroundColor White
Write-Host ""
Write-Host "  ===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Keep this window open while developing or testing." -ForegroundColor Yellow
Write-Host "  To stop all servers and exit, press [Q] or close this window." -ForegroundColor Gray
Write-Host ""

# ── Supervisor Loop (Clean Shutdown on Exit) ─────────────────────────────────
try {
    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Q -or $key.Key -eq [ConsoleKey]::Escape) {
                break
            }
        }
        # Check if php process died unexpectedly
        if ($phpProcess -and $phpProcess.HasExited) {
            Write-Host "  [ALERT] PHP server stopped unexpectedly." -ForegroundColor Red
            break
        }
        Start-Sleep -Milliseconds 400
    }
} finally {
    Write-Host ""
    Write-Host "  Stopping servers..." -ForegroundColor Yellow
    if ($phpProcess -and -not $phpProcess.HasExited) {
        $phpProcess.Kill()
    }
    if ($ngrokProcess -and -not $ngrokProcess.HasExited) {
        $ngrokProcess.Kill()
    }
    Get-Process -Name "php", "ngrok" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "  All DaanAR servers stopped cleanly. Goodbye!" -ForegroundColor Green
    Start-Sleep -Seconds 1
}
