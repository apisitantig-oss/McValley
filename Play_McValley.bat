@echo off
title McValley Updater
echo ===================================================
echo             McValley Modpack Auto-Updater          
echo ===================================================
echo.
echo [*] Checking for updates from GitHub...

powershell -NoProfile -ExecutionPolicy Bypass -Command "$local_commit = ''; if (Test-Path 'version.txt') { $local_commit = Get-Content 'version.txt' -Raw; $local_commit = $local_commit.Trim() }; $headers = @{ 'User-Agent' = 'Mozilla/5.0' }; try { $api_res = Invoke-RestMethod -Uri 'https://api.github.com/repos/apisitantig-oss/McValley/commits/main' -Headers $headers -TimeoutSec 10; $remote_commit = $api_res.sha; if ($local_commit -ne $remote_commit) { Write-Host '[*] New version detected! Downloading updates...' -ForegroundColor Green; $zip_url = 'https://github.com/apisitantig-oss/McValley/archive/refs/heads/main.zip'; $temp_zip = 'update.zip'; Invoke-WebRequest -Uri $zip_url -OutFile $temp_zip -TimeoutSec 60; Write-Host '[*] Extracting files...' -ForegroundColor Yellow; Expand-Archive -Path $temp_zip -DestinationPath 'temp_update' -Force; if (Test-Path 'temp_update\McValley-main') { if (Test-Path 'temp_update\McValley-main\mods') { Write-Host '[*] Syncing mods folder...' -ForegroundColor Yellow; if (Test-Path 'mods') { Remove-Item -Path 'mods' -Recurse -Force }; New-Item -ItemType Directory -Path 'mods' -Force | Out-Null; Copy-Item -Path 'temp_update\McValley-main\mods\*' -Destination 'mods' -Recurse -Force; }; if (Test-Path 'temp_update\McValley-main\config') { Write-Host '[*] Syncing config folder...' -ForegroundColor Yellow; if (Test-Path 'config') { Remove-Item -Path 'config' -Recurse -Force }; New-Item -ItemType Directory -Path 'config' -Force | Out-Null; Copy-Item -Path 'temp_update\McValley-main\config\*' -Destination 'config' -Recurse -Force; }; if (Test-Path 'temp_update\McValley-main\playstardew.exe') { Write-Host '[*] Syncing playstardew.exe...' -ForegroundColor Yellow; Copy-Item -Path 'temp_update\McValley-main\playstardew.exe' -Destination 'playstardew.exe' -Force; }; }; $remote_commit | Out-File 'version.txt' -Encoding ascii -NoNewline; Remove-Item -Path $temp_zip -Force; Remove-Item -Path 'temp_update' -Recurse -Force; Write-Host '[*] Update completed successfully!' -ForegroundColor Green; } else { Write-Host '[*] Your game is already up to date!' -ForegroundColor Green; } } catch { Write-Host '[!] Failed to check updates. Launching game anyway...' -ForegroundColor Red; }"

echo.
echo [*] Launching Minecraft Client (playstardew.exe)...
start "" "playstardew.exe"
exit
