# DaanAR - Startup Script
# 1. Starts PHP built-in server on port 8000
# 2. Starts ngrok tunnel to expose it
# 3. Auto-updates constants.dart with the live URL
# Usage: Right-click -> "Run with PowerShell"

$phpPath       = "php"
$apiPublicDir  = "$PSScriptRoot\daanar-api\public"
$routerFile    = "$PSScriptRoot\daanar-api\vendor\laravel\framework\src\Illuminate\Foundation\resources\server.php"
$ngrokPath     = "C:\ngrok\ngrok.exe"
$constantsFile = "$PSScriptRoot\daanar_app\lib\core\constants.dart"
$port          = 8000

Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  DaanAR Startup" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# 1. Kill any existing PHP server on port 8000
$existing = Get-Process -Name "php" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Stopping existing PHP server..." -ForegroundColor Yellow
    $existing | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# 2. Start PHP built-in server
Write-Host "Starting PHP server on port $port..." -ForegroundColor Yellow
Start-Process -FilePath $phpPath `
    -ArgumentList "-S", "0.0.0.0:$port", $routerFile `
    -WorkingDirectory $apiPublicDir `
    -WindowStyle Hidden
Start-Sleep -Seconds 3

# 3. Check API is up
try {
    $check = Invoke-WebRequest -Uri "http://127.0.0.1:$port/api/v1/landmarks" `
        -Headers @{ "Accept" = "application/json" } `
        -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
    Write-Host "  PHP API: OK (HTTP $($check.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: PHP server did not start. Check PHP is in PATH." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# 4. Kill any existing ngrok
$existingNgrok = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
if ($existingNgrok) {
    Write-Host "Stopping existing ngrok..." -ForegroundColor Yellow
    $existingNgrok | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# 5. Start ngrok
Write-Host "Starting ngrok tunnel..." -ForegroundColor Yellow
Start-Process -FilePath $ngrokPath `
    -ArgumentList "http", "--domain=letdown-twiddle-thirty.ngrok-free.dev", "127.0.0.1:$port" `
    -WindowStyle Hidden

# 6. Wait for ngrok URL
$ngrokUrl = $null
$attempts = 0
Write-Host "Waiting for ngrok" -NoNewline -ForegroundColor Yellow

while (-not $ngrokUrl -and $attempts -lt 20) {
    Start-Sleep -Milliseconds 500
    Write-Host "." -NoNewline -ForegroundColor Yellow
    $attempts++
    try {
        $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -ErrorAction SilentlyContinue
        $https = $tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1
        if ($https) { $ngrokUrl = $https.public_url }
    } catch {}
}

Write-Host ""

# 7. Update constants.dart
if ($ngrokUrl) {
    $baseUrl = "$ngrokUrl/api/v1"
    $content = Get-Content $constantsFile -Raw
    # Replace any existing baseUrl (http or https, any host)
    $updated = $content -replace "static const String baseUrl = '[^']+';" , "static const String baseUrl = '$baseUrl';"
    if ($content -ne $updated) {
        Set-Content -Path $constantsFile -Value $updated -NoNewline
        Write-Host "  constants.dart -> $baseUrl" -ForegroundColor Green
    } else {
        Write-Host "  constants.dart already up to date." -ForegroundColor Gray
    }
} else {
    Write-Host "  WARNING: Could not get ngrok URL. App will use current constants.dart." -ForegroundColor Yellow
    $ngrokUrl = "(ngrok unavailable)"
}

Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  All systems GO!" -ForegroundColor Green
Write-Host ""
Write-Host "  PHP API: http://127.0.0.1:$port/api/v1" -ForegroundColor White
Write-Host "  ngrok:   $ngrokUrl" -ForegroundColor White
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Open the app on your phone!" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit (servers keep running in background)"
