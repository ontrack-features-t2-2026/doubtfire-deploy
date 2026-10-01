@echo off
cd /d "%~dp0public-demo"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0public-demo\OnTrack.ps1"
pause
