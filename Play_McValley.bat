@echo off
title McValley Launcher
chcp 65001 >nul 2>&1
color 0A

echo.
echo  ================================================
echo       McValley - Stardew Valley Modpack
echo  ================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mcvalley_update.ps1"

pause
