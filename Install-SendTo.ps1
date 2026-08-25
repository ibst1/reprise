<#
.SYNOPSIS
    Adds three shortcuts to your personal SendTo folder: Back up, Archive, Restore.

.DESCRIPTION
    Only writes to %APPDATA%\Microsoft\Windows\SendTo, which your user owns
    - no admin, no registry editing. Afterwards the entries show up under
    right-click -> Send To.

    Run once:
        powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-SendTo.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Lang.ps1')

$sendTo = [Environment]::GetFolderPath([Environment+SpecialFolder]::SendTo)
$psExe  = Join-Path $PSHOME 'powershell.exe'
$wsh    = New-Object -ComObject WScript.Shell

$specs = @(
    [pscustomobject]@{
        Name   = (T 'sendto.backup')
        Script = 'Backup.ps1'
        Extra  = ''
        Icon   = 'shell32.dll,45'
        Desc   = (T 'sendto.backupDesc')
    },
    [pscustomobject]@{
        Name   = (T 'sendto.archive')
        Script = 'Backup.ps1'
        Extra  = ' -Move'
        Icon   = 'shell32.dll,266'
        Desc   = (T 'sendto.archiveDesc')
    },
    [pscustomobject]@{
        Name   = (T 'sendto.restore')
        Script = 'Restore.ps1'
        Extra  = ''
        Icon   = 'shell32.dll,238'
        Desc   = (T 'sendto.restoreDesc')
    }
)

foreach ($spec in $specs) {
    $scriptPath = Join-Path $PSScriptRoot $spec.Script
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Cannot find $($spec.Script) next to this script ($scriptPath)."
    }

    $lnkPath = Join-Path $sendTo ($spec.Name + '.lnk')
    $args    = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"{1}' -f $scriptPath, $spec.Extra

    $sc = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath       = $psExe
    $sc.Arguments        = $args
    $sc.WorkingDirectory = $PSScriptRoot
    $sc.IconLocation     = $spec.Icon
    $sc.Description       = $spec.Desc
    $sc.Save()

    Write-Host (T 'install.created' $lnkPath) -ForegroundColor Green
}

Write-Host ""
Write-Host (T 'install.done')
