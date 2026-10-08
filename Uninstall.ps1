<#
.SYNOPSIS
    Removes what Reprise has put on this machine: its Send To entries, any
    startup shortcut to Reprise.ahk, and the run history.

.DESCRIPTION
    A shortcut counts as Reprise's when its target or arguments point at a file
    in this folder - so entries are found whatever language they were named in,
    and nobody else's shortcuts are touched.

    The Reprise folder itself is left alone: it may be synced or a git checkout,
    and deleting it from here would delete it everywhere. Backups folders next to
    your files are never touched either.

        powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
#>
[CmdletBinding()]
param([switch] $Quiet)

. (Join-Path $PSScriptRoot 'Lang.ps1')

$wsh  = New-Object -ComObject WScript.Shell
$here = $PSScriptRoot.TrimEnd('\') + '\'
$removed = @()

foreach ($dir in [Environment]::GetFolderPath('SendTo'), [Environment]::GetFolderPath('Startup')) {
    foreach ($lnk in Get-ChildItem -LiteralPath $dir -Filter *.lnk -ErrorAction SilentlyContinue) {
        $sc = $wsh.CreateShortcut($lnk.FullName)
        if (($sc.TargetPath + ' ' + $sc.Arguments).IndexOf($here, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            Remove-Item -LiteralPath $lnk.FullName -Force
            $removed += $lnk.FullName
        }
    }
}

$historyDir = Join-Path $env:LOCALAPPDATA 'Reprise'
if (Test-Path -LiteralPath $historyDir) {
    Remove-Item -LiteralPath $historyDir -Recurse -Force
    $removed += $historyDir
}

if (-not $Quiet) {
    if ($removed.Count -eq 0) { Write-Host (T 'uninstall.nothing') }
    foreach ($r in $removed) { Write-Host (T 'uninstall.removed' $r) -ForegroundColor Green }
    Write-Host ''
    Write-Host (T 'uninstall.kept' $PSScriptRoot)
}
