<#
.SYNOPSIS
    Restores items from a Backups folder back to their original location.

.DESCRIPTION
    Counterpart to Backup.ps1. Two ways to use it:

    1. Select items INSIDE a Backups\<timestamp> folder (or the timestamp
       folder itself). The items are copied back to the source folder with the
       same relative placement they had.

    2. Select a file/folder in the MAIN FOLDER (above Backups). The script looks
       up all earlier versions in Backups\* and shows a version picker where you
       choose which version to restore. The chosen version overwrites the
       current file.

    When targets from case 1 already exist, the script asks once how collisions
    should be handled: overwrite, skip the ones that collide, or cancel
    everything.

.PARAMETER Paths
    One or more items - either inside a Backups\<timestamp> folder, or
    files/folders in the main folder that have earlier versions in Backups.

.PARAMETER Quiet
    Skips the confirmation popup on a successful restore. Picker, collision and
    error dialogs are always shown.
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Paths,

    [switch] $Quiet
)

. (Join-Path $PSScriptRoot 'Lang.ps1')

$ErrorActionPreference = 'Stop'
$backupFolderName = 'Backups'
$timestampPattern = '^\d{4}-\d{2}-\d{2}_\d{6}$'

function Show-Toast {
    param([string]$Text, [int]$Seconds = 3, [string]$Title = 'Restore complete')
    try {
        $wsh = New-Object -ComObject WScript.Shell
        [void]$wsh.Popup($Text, $Seconds, $Title, 64)
    } catch { }
}

function Show-Error {
    param([string]$Text)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($Text, 'Restore - error', 'OK', 'Error')
    } catch {
        Write-Error $Text
    }
}

function Ask-Collision {
    param([int]$Count)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $msg = (T 'restore.collision' $Count (T-Plural $Count 'backup.item' 'backup.items')) +
               (T 'restore.collYes') +
               (T 'restore.collNo') +
               (T 'restore.collCancel')
        $r = [System.Windows.Forms.MessageBox]::Show($msg, 'Restore - collision', 'YesNoCancel', 'Warning')
        switch ($r) {
            'Yes'    { return 'overwrite' }
            'No'     { return 'skip' }
            default  { return 'cancel' }
        }
    } catch {
        return 'cancel'
    }
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Format-Timestamp {
    param([string]$Name)
    if ($Name -match '^(\d{4}-\d{2}-\d{2})_(\d{2})(\d{2})(\d{2})$') {
        return ('{0} at {1}:{2}:{3}' -f $Matches[1], $Matches[2], $Matches[3], $Matches[4])
    }
    return $Name
}

# Case A: items that already live under Backups\<timestamp> -> target = original location.
function Get-RestoreJobs {
    param([string]$Path)

    $full = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
    $segments = $full -split '\\'

    $backupIdx = -1
    for ($i = $segments.Length - 2; $i -ge 0; $i--) {
        if ($segments[$i] -ieq $backupFolderName -and $segments[$i + 1] -match $timestampPattern) {
            $backupIdx = $i
            break
        }
    }
    if ($backupIdx -lt 0) { return @() }

    $originalRoot = ($segments[0..($backupIdx - 1)] -join '\')
    if ($originalRoot -match '^[A-Za-z]:$') { $originalRoot += '\' }

    $tsIdx = $backupIdx + 1
    $relSegs = @()
    if ($segments.Length -gt ($tsIdx + 1)) {
        $relSegs = $segments[($tsIdx + 1)..($segments.Length - 1)]
    }

    $jobs = @()
    if ($relSegs.Count -eq 0) {
        Get-ChildItem -LiteralPath $full -Force |
            Where-Object { $_.Name -ine 'backup-log.txt' } |
            ForEach-Object {
                $jobs += [pscustomobject]@{ Source = $_.FullName; Target = (Join-Path $originalRoot $_.Name); ForceOverwrite = $false }
            }
    } else {
        $target = Join-Path $originalRoot ($relSegs -join '\')
        $jobs += [pscustomobject]@{ Source = $full; Target = $target; ForceOverwrite = $false }
    }
    return $jobs
}

# Case B: collect the available versions in Backups\* that contain any of $Leaves.
function Get-Versions {
    param([string]$BackupsDir, [string[]]$Leaves)

    $result = @()
    Get-ChildItem -LiteralPath $BackupsDir -Directory -Force |
        Where-Object { $_.Name -match $timestampPattern } |
        Sort-Object Name -Descending |
        ForEach-Object {
            $ts = $_
            $present = 0
            $size = [long]0
            foreach ($leaf in $Leaves) {
                $lp = Join-Path $ts.FullName $leaf
                if (Test-Path -LiteralPath $lp) {
                    $present++
                    $it = Get-Item -LiteralPath $lp -Force
                    if ($it.PSIsContainer) {
                        $sum = (Get-ChildItem -LiteralPath $lp -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum
                        if ($sum) { $size += [long]$sum }
                    } else {
                        $size += [long]$it.Length
                    }
                }
            }
            if ($present -gt 0) {
                $countText = if ($Leaves.Count -gt 1) { "$present of $($Leaves.Count) items, " } else { '' }
                $result += [pscustomobject]@{
                    Folder  = $ts.FullName
                    Display = ('{0}    ({1}{2})' -f (Format-Timestamp $ts.Name), $countText, (Format-Size $size))
                }
            }
        }
    return $result
}

# Version picker (WinForms list, newest first).
function Select-Version {
    param([string]$Title, [array]$Versions)

    # Test hook: set the env variable REPRISE_AUTOSELECT=<index> to pick without UI
    # (0 = newest). Only used by automated tests; does not affect normal operation.
    if ($env:REPRISE_AUTOSELECT) {
        $i = [int]$env:REPRISE_AUTOSELECT
        if ($i -ge 0 -and $i -lt $Versions.Count) { return $Versions[$i].Folder }
        return $null
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(480, 340)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = T 'restore.pickLabel'
    $label.SetBounds(12, 10, 450, 20)

    $list = New-Object System.Windows.Forms.ListBox
    $list.SetBounds(12, 34, 444, 218)
    foreach ($v in $Versions) { [void]$list.Items.Add($v.Display) }
    if ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }
    $list.Add_DoubleClick({ $form.DialogResult = 'OK'; $form.Close() })

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = T 'restore.pickOk'
    $ok.DialogResult = 'OK'
    $ok.SetBounds(280, 262, 84, 30)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = T 'restore.pickCancel'
    $cancel.DialogResult = 'Cancel'
    $cancel.SetBounds(372, 262, 84, 30)

    $form.Controls.AddRange(@($label, $list, $ok, $cancel))
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if ($result -eq 'OK' -and $list.SelectedIndex -ge 0) {
        return $Versions[$list.SelectedIndex].Folder
    }
    return $null
}

# --- Validation ---------------------------------------------------------------
if (-not $Paths -or $Paths.Count -eq 0) {
    Show-Error (T 'restore.noItems')
    exit 1
}

# --- Sort the input into Case A (in Backups) and Case B (in the main folder) ---
$backupJobs = @()          # Case A
$mainGroups = [ordered]@{} # Case B: source folder -> list of leaf names
$notFound   = @()

foreach ($p in $Paths) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $p = $p.Trim('"')
    if (-not (Test-Path -LiteralPath $p)) { continue }

    $caseA = @(Get-RestoreJobs -Path $p)
    if ($caseA.Count -gt 0) {
        $backupJobs += $caseA
        continue
    }

    # Case B: the file is in the main folder - are there versions in Backups?
    $full   = (Resolve-Path -LiteralPath $p).Path.TrimEnd('\')
    $parent = [System.IO.Path]::GetDirectoryName($full)
    $leaf   = [System.IO.Path]::GetFileName($full)
    $backupsDir = Join-Path $parent $backupFolderName

    $hasVersion = $false
    if ($leaf -ine $backupFolderName -and (Test-Path -LiteralPath $backupsDir)) {
        $hasVersion = @(Get-ChildItem -LiteralPath $backupsDir -Directory -Force |
            Where-Object { $_.Name -match $timestampPattern -and (Test-Path -LiteralPath (Join-Path $_.FullName $leaf)) }).Count -gt 0
    }

    if ($hasVersion) {
        if (-not $mainGroups.Contains($parent)) { $mainGroups[$parent] = @() }
        $mainGroups[$parent] += $leaf
    } else {
        $notFound += $p
    }
}

# --- Case B: let the user pick a version per source folder --------------------
$caseBJobs = @()
foreach ($parent in $mainGroups.Keys) {
    $leaves     = @($mainGroups[$parent] | Select-Object -Unique)
    $backupsDir = Join-Path $parent $backupFolderName
    $versions   = @(Get-Versions -BackupsDir $backupsDir -Leaves $leaves)
    if ($versions.Count -eq 0) { continue }

    $titleName = if ($leaves.Count -eq 1) { $leaves[0] } else { T 'restore.nItems' $leaves.Count }
    $chosen = Select-Version -Title (T 'restore.pickTitle' $titleName) -Versions $versions
    if (-not $chosen) { continue }   # user cancelled for this folder

    foreach ($leaf in $leaves) {
        $src = Join-Path $chosen $leaf
        if (Test-Path -LiteralPath $src) {
            $caseBJobs += [pscustomobject]@{ Source = $src; Target = (Join-Path $parent $leaf); ForceOverwrite = $true }
        }
    }
}

$allJobs = @($backupJobs + $caseBJobs)

if ($allJobs.Count -eq 0) {
    if ($notFound.Count -gt 0) {
        Show-Error ("Found nothing to restore.`n`nSelected items must either live under a " +
                    "'$backupFolderName\<timestamp>' folder, or be a file/folder in the main folder that has " +
                    "earlier versions in Backups.`n`n" + ($notFound -join "`n"))
        exit 1
    }
    exit 0   # everything cancelled in the picker
}

# --- Collision policy for Case A (asked once) ---------------------------------
$collisions = @($allJobs | Where-Object { -not $_.ForceOverwrite -and (Test-Path -LiteralPath $_.Target) })
$policy = 'none'
if ($collisions.Count -gt 0) {
    $policy = Ask-Collision -Count $collisions.Count
    if ($policy -eq 'cancel') { exit 0 }
}

# --- Restore ------------------------------------------------------------------
$restored = 0
$skipped  = 0
$errors   = @()

foreach ($job in $allJobs) {
    $targetExists = Test-Path -LiteralPath $job.Target
    if ($targetExists -and (-not $job.ForceOverwrite) -and $policy -eq 'skip') { $skipped++; continue }

    $targetParent = [System.IO.Path]::GetDirectoryName($job.Target)
    try {
        if (-not (Test-Path -LiteralPath $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        if ($targetExists -and ($job.ForceOverwrite -or $policy -eq 'overwrite')) {
            Remove-Item -LiteralPath $job.Target -Recurse -Force
        }
        Copy-Item -LiteralPath $job.Source -Destination $targetParent -Recurse -Force
        $restored++
    } catch {
        $errors += (T 'restore.failed' $job.Source $_.Exception.Message)
    }
}

# --- Feedback -----------------------------------------------------------------
if ($errors.Count -gt 0) {
    Show-Error ((T 'restore.withErrors' $restored $skipped) + ($errors -join "`n`n"))
    exit 1
}

if (-not $Quiet) {
    $txt = "$restored items restored."
    if ($skipped -gt 0) { $txt += "`n$skipped skipped (already existed)." }
    Show-Toast -Text $txt
}

exit 0
