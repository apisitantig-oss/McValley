$ErrorActionPreference = 'Continue'
$headers = @{ 'User-Agent' = 'McValley-Launcher/2.0' }
$owner = 'apisitantig-oss'
$repo = 'McValley'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# สร้าง Desktop Shortcut ถ้ายังไม่มี
$shortcutName = "เล่น McValley - กดตัวนี้เพื่ออัปเดตและเล่นเกม.lnk"
$shortcutPath = [System.IO.Path]::Combine([Environment]::GetFolderPath('Desktop'), $shortcutName)
if (!(Test-Path $shortcutPath)) {
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $sc = $WshShell.CreateShortcut($shortcutPath)
        $sc.TargetPath = Join-Path $scriptDir "Play_McValley.bat"
        $sc.WorkingDirectory = $scriptDir
        $sc.IconLocation = (Join-Path $scriptDir "playstardew.exe") + ",0"
        $sc.Description = "คลิกตัวนี้เพื่ออัปเดตและเล่น McValley"
        $sc.Save()
        Write-Host " [*] สร้าง Shortcut บน Desktop แล้ว!" -ForegroundColor Magenta
    } catch {
        Write-Host " [!] สร้าง Shortcut ไม่ได้: $_" -ForegroundColor DarkGray
    }
}

# โหลด version ปัจจุบัน
$versionFile = Join-Path $scriptDir "version.txt"
$local_commit = ''
if (Test-Path $versionFile) {
    $local_commit = (Get-Content $versionFile -Raw).Trim()
}

# ตรวจสอบ GitHub
Write-Host " [*] กำลังตรวจสอบอัปเดต..." -ForegroundColor Cyan
try {
    $api_res = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/commits/main" -Headers $headers -TimeoutSec 10
    $remote_commit = $api_res.sha

    if ($local_commit -eq $remote_commit) {
        Write-Host " [OK] เกมอัปเดตแล้ว! ไม่มีอะไรใหม่" -ForegroundColor Green
    } else {
        $changed_files = $null
        $compare = $null

        if ($local_commit -ne '') {
            Write-Host " [*] พบอัปเดตใหม่! กำลังตรวจสอบไฟล์ที่เปลี่ยน..." -ForegroundColor Yellow
            try {
                $compare_url = "https://api.github.com/repos/$owner/$repo/compare/$local_commit...$remote_commit"
                $compare = Invoke-RestMethod -Uri $compare_url -Headers $headers -TimeoutSec 15
                $changed_files = $compare.files | Where-Object { $_.status -ne 'removed' } | Select-Object -ExpandProperty filename
                Write-Host " [*] ไฟล์ที่เปลี่ยน: $($changed_files.Count) ไฟล์" -ForegroundColor Yellow

                # self-update bat ถ้า bat เปลี่ยน
                $bat_changed = $compare.files | Where-Object { $_.filename -eq 'Play_McValley.bat' }
                if ($bat_changed) {
                    Write-Host " [*] Launcher ถูกอัปเดต กำลังดาวน์โหลดตัวใหม่..." -ForegroundColor Magenta
                    $bat_url = "https://raw.githubusercontent.com/$owner/$repo/main/Play_McValley.bat"
                    $newBat = Join-Path $scriptDir "Play_McValley_new.bat"
                    Invoke-WebRequest -Uri $bat_url -OutFile $newBat -TimeoutSec 30
                    $remote_commit | Out-File $versionFile -Encoding ascii -NoNewline
                    Write-Host " [OK] Launcher อัปเดตแล้ว รีสตาร์ท..." -ForegroundColor Green
                    Start-Process $newBat -WorkingDirectory $scriptDir
                    Start-Sleep -Milliseconds 800
                    Remove-Item (Join-Path $scriptDir "Play_McValley.bat") -Force -ErrorAction SilentlyContinue
                    Rename-Item $newBat (Join-Path $scriptDir "Play_McValley.bat")
                    exit
                }
            } catch {
                Write-Host " [!] ดูความต่างไม่ได้ จะโหลดทั้งหมดแทน..." -ForegroundColor Red
                $changed_files = $null
                $compare = $null
            }
        } else {
            Write-Host " [*] ติดตั้งครั้งแรก กำลังดาวน์โหลดทั้งหมด..." -ForegroundColor Cyan
        }

        $base_url = "https://raw.githubusercontent.com/$owner/$repo/main"
        $folders_to_sync = @('mods', 'config')

        if ($changed_files -eq $null) {
            # Full download
            $zip_url = "https://github.com/$owner/$repo/archive/refs/heads/main.zip"
            $zipPath = Join-Path $scriptDir "update.zip"
            $tempDir = Join-Path $scriptDir "temp_update"
            Write-Host " [*] กำลังดาวน์โหลด zip..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $zip_url -OutFile $zipPath -TimeoutSec 120
            Write-Host " [*] กำลังแตกไฟล์..." -ForegroundColor Yellow
            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
            $src = Join-Path $tempDir "McValley-main"
            foreach ($folder in $folders_to_sync) {
                $srcFolder = Join-Path $src $folder
                $dstFolder = Join-Path $scriptDir $folder
                if (Test-Path $srcFolder) {
                    if (Test-Path $dstFolder) { Remove-Item $dstFolder -Recurse -Force }
                    New-Item -ItemType Directory -Path $dstFolder -Force | Out-Null
                    Copy-Item "$srcFolder\*" -Destination $dstFolder -Recurse -Force
                    Write-Host " [OK] ซิงค์ $folder/" -ForegroundColor Green
                }
            }
            $exeSrc = Join-Path $src "playstardew.exe"
            if (Test-Path $exeSrc) {
                Copy-Item $exeSrc -Destination (Join-Path $scriptDir "playstardew.exe") -Force
                Write-Host " [OK] ซิงค์ playstardew.exe" -ForegroundColor Green
            }
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            # Delta download
            $downloaded = 0
            $skipped = 0
            foreach ($file in $changed_files) {
                $topFolder = ($file -split '/')[0]
                if ($folders_to_sync -contains $topFolder -or $file -eq 'playstardew.exe') {
                    $destPath = Join-Path $scriptDir ($file.Replace('/', '\'))
                    $destDir = Split-Path $destPath -Parent
                    if ($destDir -ne '' -and !(Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                    $dlUrl = "$base_url/$($file -replace ' ', '%20')"
                    try {
                        Invoke-WebRequest -Uri $dlUrl -OutFile $destPath -TimeoutSec 60
                        Write-Host " [DL] $file" -ForegroundColor Cyan
                        $downloaded++
                    } catch {
                        Write-Host " [!] ดาวน์โหลดไม่ได้: $file" -ForegroundColor Red
                    }
                } else {
                    $skipped++
                }
            }
            if ($compare) {
                $removed = $compare.files | Where-Object { $_.status -eq 'removed' } | Select-Object -ExpandProperty filename
                foreach ($file in $removed) {
                    $destPath = Join-Path $scriptDir ($file.Replace('/', '\'))
                    if (Test-Path $destPath) {
                        Remove-Item $destPath -Force
                        Write-Host " [X] ลบ: $file" -ForegroundColor DarkGray
                    }
                }
            }
            Write-Host " [OK] อัปเดต $downloaded ไฟล์ (ข้าม $skipped ไฟล์)" -ForegroundColor Green
        }

        $remote_commit | Out-File $versionFile -Encoding ascii -NoNewline
        Write-Host " [OK] อัปเดตเสร็จแล้ว!" -ForegroundColor Green
    }
} catch {
    Write-Host " [!] เชื่อมต่อ GitHub ไม่ได้: $_" -ForegroundColor Red
    Write-Host " [*] เปิดเกมโดยไม่อัปเดต..." -ForegroundColor Yellow
}

# เปิดเกม
Write-Host ""
Write-Host " [*] กำลังเปิด McValley..." -ForegroundColor Green
$exePath = Join-Path $scriptDir "playstardew.exe"
if (Test-Path $exePath) {
    Start-Process $exePath -WorkingDirectory $scriptDir
} else {
    Write-Host " [!] หา playstardew.exe ไม่เจอ! ตรวจสอบโฟลเดอร์" -ForegroundColor Red
    pause
}
