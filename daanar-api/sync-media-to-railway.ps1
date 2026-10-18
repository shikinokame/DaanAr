# sync-media-to-railway.ps1
$ErrorActionPreference = "Stop"

$railwayUrl = "https://daanar-production.up.railway.app"
$syncUrl = "$railwayUrl/api/v1/internal/sync-media"
$checkUrl = "$railwayUrl/api/v1/internal/check-media"
$secret = "daanar_sync_secret_2026"

$baseStorage = "c:\Users\Harvinjee\new daanAr\daanar-api\storage\app\public"
$folders = @("landmarks\hero", "landmarks\models")

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Syncing Media to Railway Persistent Volume" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if endpoint is live
try {
    $check = Invoke-RestMethod -Uri $checkUrl -Method GET -TimeoutSec 10
    Write-Host "Endpoint is online! Current files in volume: $($check.count)" -ForegroundColor Green
} catch {
    Write-Host "Railway is still deploying or endpoint not found yet. Error: $_" -ForegroundColor Yellow
    exit 1
}

$existingFiles = @($check.files)

$totalUploaded = 0
$totalSkipped = 0
$totalFailed = 0

foreach ($folder in $folders) {
    $fullFolderPath = Join-Path $baseStorage $folder
    if (-not (Test-Path $fullFolderPath)) {
        Write-Host "Folder not found: $fullFolderPath" -ForegroundColor Yellow
        continue
    }

    $files = Get-ChildItem -Path $fullFolderPath -File
    Write-Host "`nProcessing folder: $folder ($($files.Count) files)" -ForegroundColor Cyan

    foreach ($file in $files) {
        $relativePath = "$folder\$($file.Name)" -replace '\\', '/'
        $sizeMB = [math]::Round($file.Length / 1MB, 2)

        if ($existingFiles -contains $relativePath) {
            Write-Host "Skipping: $relativePath (already on Railway) [OK]" -ForegroundColor DarkGreen
            $totalSkipped++
            continue
        }

        Write-Host "Uploading: $relativePath ($sizeMB MB)... " -NoNewline

        $success = $false
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            # Upload with curl.exe with generous timeouts
            $response = & curl.exe --connect-timeout 30 --max-time 900 -s -w "\nHTTP_STATUS:%{http_code}" -X POST $syncUrl `
                -H "X-Sync-Secret: $secret" `
                -F "path=$relativePath" `
                -F "file=@$($file.FullName)"

            if ($response -match "HTTP_STATUS:200") {
                Write-Host "OK!" -ForegroundColor Green
                $totalUploaded++
                $success = $true
                break
            } else {
                Write-Host "(Attempt $attempt failed, retrying in 3s)... " -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }

        if (-not $success) {
            Write-Host "FAILED after 3 attempts!" -ForegroundColor Red
            Write-Host "Response: $response" -ForegroundColor DarkRed
            $totalFailed++
        }
    }
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Finished! Uploaded: $totalUploaded, Skipped: $totalSkipped, Failed: $totalFailed" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Final check
$verify = Invoke-RestMethod -Uri $checkUrl -Method GET
Write-Host "Files now verified in Railway Volume: $($verify.count)" -ForegroundColor Green

