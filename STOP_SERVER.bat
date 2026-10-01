@echo off
title Stopping DaanAR Servers...
cd /d "%~dp0"
echo.
echo Stopping all DaanAR PHP servers and ngrok tunnels...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process php, ngrok -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; $conn = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue; if ($conn) { foreach ($c in $conn) { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue } }"
echo.
echo [OK] All DaanAR servers stopped and port 8000 is free!
timeout /t 3
