@echo off
title DaanAR - Server & Tunnel Manager
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-server.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Startup failed.
    pause
)
