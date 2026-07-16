@echo off
title McValley Launcher
chcp 65001 >nul 2>&1
color 0A

echo.
echo  ╔════════════════════════════════════════════════════╗
echo  ║         McValley - Stardew Valley Modpack          ║
echo  ║              กำลังตรวจสอบอัปเดต...                ║
echo  ╚════════════════════════════════════════════════════╝
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference = 'Stop'; ^
$headers = @{ 'User-Agent' = 'McValley-Launcher/2.0' }; ^
$owner = 'apisitantig-oss'; $repo = 'McValley'; ^
$local_commit = ''; ^
if (Test-Path 'version.txt') { $local_commit = (Get-Content 'version.txt' -Raw).Trim() }; ^
try { ^
  $api_res = Invoke-RestMethod -Uri \"https://api.github.com/repos/$owner/$repo/commits/main\" -Headers $headers -TimeoutSec 10; ^
  $remote_commit = $api_res.sha; ^
  if ($local_commit -eq $remote_commit) { ^
    Write-Host ' [✓] เกมอัปเดตแล้ว! กำลังเปิดเกม...' -ForegroundColor Green; ^
  } else { ^
    if ($local_commit -eq '') { ^
      Write-Host ' [*] ติดตั้งครั้งแรก กำลังดาวน์โหลด...' -ForegroundColor Cyan; ^
      $changed_files = $null; ^
    } else { ^
      Write-Host ' [*] พบอัปเดตใหม่! กำลังตรวจสอบไฟล์ที่เปลี่ยน...' -ForegroundColor Yellow; ^
      try { ^
        $compare_url = \"https://api.github.com/repos/$owner/$repo/compare/$($local_commit)...$($remote_commit)\"; ^
        $compare = Invoke-RestMethod -Uri $compare_url -Headers $headers -TimeoutSec 15; ^
        $changed_files = $compare.files | Where-Object { $_.status -ne 'removed' } | Select-Object -ExpandProperty filename; ^
        Write-Host \" [*] ไฟล์ที่เปลี่ยน: $($changed_files.Count) ไฟล์\" -ForegroundColor Yellow; ^
      } catch { ^
        Write-Host ' [!] เปรียบไม่ได้ ดาวน์โหลดทั้งหมดแทน...' -ForegroundColor Red; ^
        $changed_files = $null; ^
      } ^
    }; ^
    $base_url = \"https://raw.githubusercontent.com/$owner/$repo/main\"; ^
    $folders_to_sync = @('mods', 'config'); ^
    if ($changed_files -eq $null) { ^
      Write-Host ' [*] กำลังดาวน์โหลดทั้งหมด...' -ForegroundColor Yellow; ^
      $zip_url = \"https://github.com/$owner/$repo/archive/refs/heads/main.zip\"; ^
      Invoke-WebRequest -Uri $zip_url -OutFile 'update.zip' -TimeoutSec 120; ^
      Write-Host ' [*] กำลังแตกไฟล์...' -ForegroundColor Yellow; ^
      Expand-Archive -Path 'update.zip' -DestinationPath 'temp_update' -Force; ^
      $src = 'temp_update\\McValley-main'; ^
      foreach ($folder in $folders_to_sync) { ^
        if (Test-Path \"$src\\$folder\") { ^
          if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }; ^
          New-Item -ItemType Directory -Path $folder -Force | Out-Null; ^
          Copy-Item \"$src\\$folder\\*\" -Destination $folder -Recurse -Force; ^
          Write-Host \" [✓] ซิงค์ $folder/\" -ForegroundColor Green; ^
        } ^
      }; ^
      if (Test-Path \"$src\\playstardew.exe\") { Copy-Item \"$src\\playstardew.exe\" -Destination 'playstardew.exe' -Force; Write-Host ' [✓] ซิงค์ playstardew.exe' -ForegroundColor Green }; ^
      Remove-Item 'update.zip' -Force -ErrorAction SilentlyContinue; ^
      Remove-Item 'temp_update' -Recurse -Force -ErrorAction SilentlyContinue; ^
    } else { ^
      $downloaded = 0; $skipped = 0; ^
      foreach ($file in $changed_files) { ^
        $target_folder = ($file -split '/')[0]; ^
        if ($folders_to_sync -contains $target_folder -or $file -eq 'playstardew.exe') { ^
          $dest_path = $file.Replace('/', '\\'); ^
          $dest_dir = Split-Path $dest_path -Parent; ^
          if ($dest_dir -ne '' -and !(Test-Path $dest_dir)) { New-Item -ItemType Directory -Path $dest_dir -Force | Out-Null }; ^
          $download_url = \"$base_url/$($file -replace ' ', '%20')\"; ^
          try { ^
            Invoke-WebRequest -Uri $download_url -OutFile $dest_path -TimeoutSec 30; ^
            Write-Host \" [↓] $file\" -ForegroundColor Cyan; ^
            $downloaded++ ^
          } catch { Write-Host \" [!] ดาวน์โหลดไม่ได้: $file\" -ForegroundColor Red } ^
        } else { $skipped++ } ^
      }; ^
      $removed = $compare.files | Where-Object { $_.status -eq 'removed' } | Select-Object -ExpandProperty filename; ^
      foreach ($file in $removed) { ^
        $dest_path = $file.Replace('/', '\\'); ^
        if (Test-Path $dest_path) { Remove-Item $dest_path -Force; Write-Host \" [x] ลบ: $file\" -ForegroundColor DarkGray } ^
      }; ^
      Write-Host \" [✓] อัปเดต $downloaded ไฟล์ (ข้าม $skipped ไฟล์ที่ไม่เกี่ยว)\" -ForegroundColor Green; ^
    }; ^
    $remote_commit | Out-File 'version.txt' -Encoding ascii -NoNewline; ^
    Write-Host ' [✓] อัปเดตเสร็จแล้ว!' -ForegroundColor Green; ^
  } ^
} catch { ^
  Write-Host \" [!] เชื่อมต่อ GitHub ไม่ได้: $_\" -ForegroundColor Red; ^
  Write-Host ' [*] กำลังเปิดเกมโดยไม่อัปเดต...' -ForegroundColor Yellow ^
}"

echo.
echo  [*] กำลังเปิด McValley...
start "" "playstardew.exe"
exit
