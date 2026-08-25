<#
.SYNOPSIS
    Creates a timestamped backup of the selected files/folders in a "Backups" subfolder.

.DESCRIPTION
    The engine of the backup tool. Called from the Send To menu or AutoHotkey.
    Takes one or more paths. For each source folder it creates
        <source folder>\Backups\<yyyy-MM-dd_HHmmss>\
    and the selected items are copied there with their original names (and file extensions) kept.

    Every run gets its own timestamped subfolder -> always a new copy,
    no name collisions, file extensions intact so the copies open directly.

.PARAMETER Paths
    One or more file/folder paths. Filled in automatically when items are sent
    via "Send To -> Backup" or from AutoHotkey.

.PARAMETER Quiet
    Skips the confirmation popup on a successful backup (AutoHotkey shows its own tooltip).
    Errors are always shown, even in quiet mode.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Paths,

    # Archive mode: delete the original once the copy has been verified.
    [switch] $Move,

    [switch] $Quiet
)

. (Join-Path $PSScriptRoot 'Lang.ps1')

$ErrorActionPreference = 'Stop'
$backupFolderName = 'Backups'
$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'

function Test-BackupIntegrity {
    # Verifies that the copy is complete before the original may be deleted.
    param([string]$Source, [string]$Copy)
    if (-not (Test-Path -LiteralPath $Copy)) { return $false }
    $src = Get-Item -LiteralPath $Source -Force
    if ($src.PSIsContainer) {
        $s = Get-ChildItem -LiteralPath $Source -Recurse -File -Force | Measure-Object -Property Length -Sum
        $c = Get-ChildItem -LiteralPath $Copy   -Recurse -File -Force | Measure-Object -Property Length -Sum
        return ($s.Count -eq $c.Count) -and ($s.Sum -eq $c.Sum)
    }
    return ((Get-Item -LiteralPath $Copy -Force).Length -eq $src.Length)
}

function Show-Toast {
    param([string]$Text, [int]$Seconds = 3, [string]$Title = '')
    if (-not $Title) { $Title = T 'backup.doneBackup' }
    try {
        $wsh = New-Object -ComObject WScript.Shell
        # 64 = information icon; the timeout makes the box close itself
        [void]$wsh.Popup($Text, $Seconds, $Title, 64)
    } catch { }
}

function Show-Error {
    param([string]$Text)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($Text, (T 'backup.titleBackup') + ' - error', 'OK', 'Error')
    } catch {
        Write-Error $Text
    }
}

# --- Validation ---------------------------------------------------------------
if (-not $Paths -or $Paths.Count -eq 0) {
    Show-Error (T 'backup.noPaths')
    exit 1
}

$items = @()
foreach ($p in $Paths) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $p = $p.Trim('"')
    if (Test-Path -LiteralPath $p) {
        $items += (Resolve-Path -LiteralPath $p).Path
    }
}

if ($items.Count -eq 0) {
    Show-Error (T 'backup.noValid')
    exit 1
}

# --- Copying ------------------------------------------------------------------
# Group by source folder so items in the same folder land in the same run folder.
$groups = [ordered]@{}
foreach ($item in $items) {
    $parent = [System.IO.Path]::GetDirectoryName($item)
    if (-not $groups.Contains($parent)) { $groups[$parent] = @() }
    $groups[$parent] += $item
}

$copied = 0
$moved = 0
$errors = @()
$destinations = @()

foreach ($parent in $groups.Keys) {
    $groupItems = $groups[$parent]
    $backupRoot = Join-Path $parent $backupFolderName
    $dest = Join-Path $backupRoot $timestamp

    try {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    } catch {
        $errors += "Could not create destination folder: $dest`n$($_.Exception.Message)"
        continue
    }
    $destinations += $dest
    $groupCopied = 0

    foreach ($item in $groupItems) {
        $name = [System.IO.Path]::GetFileName($item)
        # Skip the Backups folder itself if it happens to be selected.
        if ($name -ieq $backupFolderName) { continue }
        try {
            Copy-Item -LiteralPath $item -Destination $dest -Recurse -Force
            $copied++
            $groupCopied++
        } catch {
            $errors += "Could not copy: $item`n$($_.Exception.Message)"
            continue
        }

        # Archive mode: delete the original - but only after the copy is verified.
        if ($Move) {
            $copiedPath = Join-Path $dest $name
            if (Test-BackupIntegrity -Source $item -Copy $copiedPath) {
                try {
                    Remove-Item -LiteralPath $item -Recurse -Force
                    $moved++
                } catch {
                    $errors += "The copy was created but the original could not be deleted: $item`n$($_.Exception.Message)"
                }
            } else {
                $errors += "Keeping the original - the copy could not be verified: $item"
            }
        }
    }

    # One log line per Backups folder.
    try {
        $verb = if ($Move) { 'ARCHIVE' } else { 'BACKUP' }
        $unit = T-Plural $groupCopied 'backup.item' 'backup.items'
        $logLine = '{0}  [{1}]  ->  {2}  ({3} {4})' -f $timestamp, $verb, $dest, $groupCopied, $unit
        Add-Content -LiteralPath (Join-Path $backupRoot 'backup-log.txt') -Value $logLine -Encoding UTF8
    } catch { }
}

# --- Feedback -----------------------------------------------------------------
$title = if ($Move) { T 'backup.titleArchive' } else { T 'backup.titleBackup' }

if ($errors.Count -gt 0) {
    Show-Error ((T 'backup.withErrors' $title $copied (T-Plural $copied 'backup.item' 'backup.items')) +
                $(if ($Move) { " ($moved " + (T-Plural $moved 'backup.original' 'backup.originals') + ")" } else { '' }) +
                "`n`nErrors:`n" + ($errors -join "`n`n"))
    exit 1
}

if (-not $Quiet) {
    $where = (($destinations | Select-Object -Unique) -join "`n")
    if ($Move) {
        Show-Toast -Title (T 'backup.doneArchive') -Text (T 'backup.movedTo' $copied (T-Plural $copied 'backup.item' 'backup.items') $moved (T-Plural $moved 'backup.original' 'backup.originals') $where)
    } else {
        Show-Toast -Title (T 'backup.doneBackup') -Text (T 'backup.copiedTo' $copied (T-Plural $copied 'backup.item' 'backup.items') $where)
    }
}

exit 0
