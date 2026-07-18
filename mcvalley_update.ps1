$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$owner = 'apisitantig-oss'
$repo = 'McValley'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path)).TrimEnd('\') + '\'
$headers = @{ 'User-Agent' = 'McValley-Launcher/3.0' }
$versionFile = Join-Path $root 'version.txt'

function Status([string]$name, [string]$detail = '') {
    Write-Output ("STATUS|{0}|{1}" -f $name, $detail)
}

function Is-Managed([string]$path) {
    return $path -eq 'playstardew.exe' -or
           $path -eq 'resourcepacks/stardew_pack.zip' -or
           $path.StartsWith('mods/', [StringComparison]::OrdinalIgnoreCase) -or
           $path.StartsWith('config/', [StringComparison]::OrdinalIgnoreCase)
}

function Safe-Path([string]$relative) {
    if ([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative)) {
        throw "Unsafe update path: $relative"
    }
    $full = [IO.Path]::GetFullPath((Join-Path $root $relative.Replace('/', '\')))
    if (!$full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe update path: $relative"
    }
    return $full
}

try {
    Status 'Checking'
    $local = if (Test-Path -LiteralPath $versionFile) { (Get-Content -LiteralPath $versionFile -Raw).Trim() } else { '' }
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/commits/main" -Headers $headers -TimeoutSec 12
    $remote = [string]$latest.sha

    if ($local -eq $remote) {
        Status 'Current'
        exit 0
    }
    if ($local -notmatch '^[0-9a-f]{40}$' -or $remote -notmatch '^[0-9a-f]{40}$') {
        Status 'ReinstallRequired'
        exit 3
    }

    $compare = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/compare/$local...$remote" -Headers $headers -TimeoutSec 20
    if ($compare.status -notin @('ahead', 'identical')) {
        Status 'ReinstallRequired'
        exit 3
    }

    $downloads = @($compare.files | Where-Object { $_.status -ne 'removed' -and (Is-Managed $_.filename) })
    $removals = @($compare.files | Where-Object { $_.status -eq 'removed' -and (Is-Managed $_.filename) })
    $stageRoot = Safe-Path ".mcvalley-update/$remote"

    for ($i = 0; $i -lt $downloads.Count; $i++) {
        $file = $downloads[$i]
        $stage = [IO.Path]::GetFullPath((Join-Path $stageRoot $file.filename.Replace('/', '\')))
        if (!$stage.StartsWith($stageRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe stage path" }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($stage)) | Out-Null
        $encoded = (($file.filename -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
        $url = "https://raw.githubusercontent.com/$owner/$repo/$remote/$encoded"
        Status 'Downloading' ("{0}/{1}|{2}" -f ($i + 1), $downloads.Count, $file.filename)
        Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -OutFile $stage -TimeoutSec 120
        if ((Get-Item -LiteralPath $stage).Length -le 0) { throw "Downloaded file is empty: $($file.filename)" }
    }

    Status 'Applying'
    foreach ($file in $downloads) {
        $source = [IO.Path]::GetFullPath((Join-Path $stageRoot $file.filename.Replace('/', '\')))
        $target = Safe-Path $file.filename
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        if (Test-Path -LiteralPath $target) {
            $backup = $target + '.mcvalley.bak'
            if (Test-Path -LiteralPath $backup) { [IO.File]::Delete($backup) }
            [IO.File]::Replace($source, $target, $backup, $true)
            [IO.File]::Delete($backup)
        } else {
            [IO.File]::Move($source, $target)
        }
    }

    foreach ($file in $removals) {
        $target = Safe-Path $file.filename
        if (Test-Path -LiteralPath $target) { [IO.File]::Delete($target) }
    }

    [IO.File]::WriteAllText($versionFile, $remote, [Text.Encoding]::ASCII)
    if (Test-Path -LiteralPath $stageRoot) { [IO.Directory]::Delete($stageRoot, $true) }
    Status 'Done' ("$($downloads.Count)")
    exit 0
} catch {
    Status 'Failed' $_.Exception.Message
    exit 1
}
