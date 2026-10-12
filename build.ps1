# build.ps1 - builds the portable Reprise release zip into dist\.
# Downloads the AutoHotkey v2 base into build\ on first run and caches it there.
# Works in Windows PowerShell 5.1 and PowerShell 7 (used by the GitHub Actions
# release workflow).
#
# The zip ships the UNMODIFIED official AutoHotkey64.exe renamed to Reprise.exe,
# next to the plain-text scripts: run with no arguments, the interpreter loads the
# script matching its own name (Reprise.ahk). Same reasoning as DalSegno - a stock
# interpreter keeps its reputation with Defender, an Ahk2Exe build does not.
#
# Version: -Version, else the pushed tag (v2026.10.12 -> 2026.10.12), else today.
param([string]$Version)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$root = $PSScriptRoot
$tools = Join-Path $root 'build'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $tools | Out-Null

if (-not $Version) {
    $Version = if ($env:GITHUB_REF_NAME -match '^v(.+)$') { $Matches[1] } else { Get-Date -Format 'yyyy.M.d' }
}
Write-Host "Building Reprise $Version"

$base = Join-Path $tools 'base\AutoHotkey64.exe'
if (-not (Test-Path $base)) {
    Write-Host 'Downloading AutoHotkey v2 base...'
    $rels = Invoke-RestMethod 'https://api.github.com/repos/AutoHotkey/AutoHotkey/releases'
    $v2 = $rels | Where-Object { $_.tag_name -like 'v2.0*' } | Select-Object -First 1
    $asset = $v2.assets | Where-Object { $_.name -like 'AutoHotkey_2*.zip' } | Select-Object -First 1
    Invoke-WebRequest $asset.browser_download_url -OutFile (Join-Path $tools 'ahk2.zip')
    Expand-Archive (Join-Path $tools 'ahk2.zip') (Join-Path $tools 'base') -Force
}

# Test-Reprise.ps1 stays out: it is for development, not for users.
$files = @('Reprise.ahk', 'Backup.ps1', 'Restore.ps1', 'Lang.ps1', 'Install-SendTo.ps1',
    'Uninstall.ps1', 'Reprise.ini', 'README.md')
foreach ($f in $files) {
    if (-not (Test-Path (Join-Path $root $f))) { throw "Missing $f in $root" }
}

# clear dist with retries - OneDrive/AV can hold freshly written files briefly
if (Test-Path $dist) {
    $done = $false
    foreach ($i in 1..5) {
        try {
            Remove-Item $dist -Recurse -Force -ErrorAction Stop
            $done = $true
            break
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    if (-not $done) { throw "Could not clear $dist - is Reprise.exe running or the folder open?" }
}
$stage = Join-Path $dist 'Reprise'
New-Item -ItemType Directory -Force (Join-Path $stage 'icons') | Out-Null

# the renamed stock interpreter auto-loads Reprise.ahk beside it
Copy-Item $base (Join-Path $stage 'Reprise.exe')
foreach ($f in $files) { Copy-Item (Join-Path $root $f) $stage }
Copy-Item (Join-Path $root 'icons\*.ico') (Join-Path $stage 'icons')
if (Test-Path (Join-Path $root 'LICENSE')) { Copy-Item (Join-Path $root 'LICENSE') $stage }

# the zip holds one Reprise\ folder, so unzipping never scatters files - the
# scripts find each other from wherever that folder ends up
$zip = Join-Path $dist "Reprise-$Version.zip"
Compress-Archive -Path $stage -DestinationPath $zip -Force
Write-Host "Done: $zip"
