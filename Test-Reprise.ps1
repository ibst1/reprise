<#
.SYNOPSIS
    Checks Reprise without touching anything you own: both languages, both engines.

.DESCRIPTION
    Run it after editing Lang.ps1 or either engine. It verifies that

      * every string key exists in BOTH languages, and that no key is left
        untranslated (identical in sv and en) unless it is deliberately shared,
      * every T '…' key used by the scripts actually exists in the table,
      * the AutoHotkey layer's own small table has the same keys in both languages,
      * backup, archive and restore actually work, in a temp folder of its own.

    Nothing outside %TEMP% is written, and no scheduled task, shortcut or
    registry value is touched.
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'Lang.ps1')

$pass = 0; $fail = 0
function Check($label, $ok, $detail = '') {
    if ($ok) { $script:pass++; Write-Host "PASS  $label" -ForegroundColor DarkGreen }
    else     { $script:fail++; Write-Host "FAIL  $label $detail" -ForegroundColor Red }
}

# ── encoding ─────────────────────────────────────────────────────────────────
# Windows PowerShell 5.1 reads a BOM-less file as ANSI, and AutoHotkey does the
# same, so any file holding å/ä/ö MUST carry a UTF-8 BOM or its Swedish comes out
# as "tidsstÃ¤mplad" — which then ends up in Send To entry names, on disk.
foreach ($f in 'Lang.ps1', 'Reprise.ahk', 'Backup.ps1', 'Restore.ps1', 'Install-SendTo.ps1') {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $f))
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $nonAscii = @($bytes | Where-Object { $_ -gt 127 }).Count -gt 0
    Check "$f is readable: non-ASCII implies a BOM" (-not $nonAscii -or $hasBom) `
          "(non-ASCII=$nonAscii BOM=$hasBom)"
}

# ── the table itself ─────────────────────────────────────────────────────────
$en = $script:RepriseStrings['en']
$sv = $script:RepriseStrings['sv']
$onlyEn = @($en.Keys | Where-Object { -not $sv.ContainsKey($_) })
$onlySv = @($sv.Keys | Where-Object { -not $en.ContainsKey($_) })
Check 'every key exists in both languages' ($onlyEn.Count -eq 0 -and $onlySv.Count -eq 0) `
      ("en-only: [$($onlyEn -join ', ')] sv-only: [$($onlySv -join ', ')]")

# Shared spellings are fine, but list them so a forgotten translation is visible.
$shared = @($en.Keys | Where-Object { $sv.ContainsKey($_) -and $sv[$_] -eq $en[$_] })
$expectedShared = @('backup.titleBackup', 'backup.original')
$unexpected = @($shared | Where-Object { $expectedShared -notcontains $_ })
Check 'no key is accidentally identical in both languages' ($unexpected.Count -eq 0) `
      ("identical: [$($unexpected -join ', ')]")

# ── keys the scripts ask for must exist ──────────────────────────────────────
$used = @()
foreach ($f in 'Backup.ps1', 'Restore.ps1', 'Install-SendTo.ps1') {
    $text = Get-Content -LiteralPath (Join-Path $PSScriptRoot $f) -Raw
    foreach ($m in [regex]::Matches($text, "T(?:-Plural)?\s+(?:\`$\w+\s+)?'([a-z]+\.[A-Za-z]+)'")) {
        $used += $m.Groups[1].Value
    }
    foreach ($m in [regex]::Matches($text, "'([a-z]+\.[A-Za-z]+)'\s*'([a-z]+\.[A-Za-z]+)'")) {
        $used += $m.Groups[1].Value; $used += $m.Groups[2].Value
    }
}
$used = $used | Select-Object -Unique
$missing = @($used | Where-Object { -not $en.ContainsKey($_) })
Check "all $($used.Count) keys used by the scripts exist" ($missing.Count -eq 0) `
      ("missing: [$($missing -join ', ')]")

# ── T itself ─────────────────────────────────────────────────────────────────
Check 'T fills in placeholders' ((T 'restore.pickTitle' 'x') -like '*x*')
Check 'T on an unknown key is visible, not empty' ((T 'no.such.key') -eq '[no.such.key]')
Check 'T-Plural picks the singular' ((T-Plural 1 'backup.item' 'backup.items') -eq (T 'backup.item'))
Check 'T-Plural picks the plural'   ((T-Plural 2 'backup.item' 'backup.items') -eq (T 'backup.items'))

# ── the AutoHotkey table ─────────────────────────────────────────────────────
$ahk = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Reprise.ahk') -Raw
$ahkEn = @([regex]::Matches($ahk.Substring($ahk.IndexOf('"en", Map('), $ahk.IndexOf('"sv", Map(') - $ahk.IndexOf('"en", Map(')), '"(\w+)",\s+"') | ForEach-Object { $_.Groups[1].Value })
$ahkSv = @([regex]::Matches($ahk.Substring($ahk.IndexOf('"sv", Map(')), '"(\w+)",\s+"') | ForEach-Object { $_.Groups[1].Value })
Check 'the AHK table has the same keys in both languages' (($ahkEn -join ',') -eq ($ahkSv -join ',')) `
      ("en: [$($ahkEn -join ',')] sv: [$($ahkSv -join ',')]")
$ahkUsed = @([regex]::Matches($ahk, 'T\("(\w+)"\)') | ForEach-Object { $_.Groups[1].Value }) | Select-Object -Unique
$ahkMissing = @($ahkUsed | Where-Object { $ahkEn -notcontains $_ })
Check 'every T("…") in the AHK layer exists' ($ahkMissing.Count -eq 0) "missing: [$($ahkMissing -join ', ')]"

# ── the engines, end to end, in a temp folder ────────────────────────────────
$t = Join-Path $env:TEMP ('reprise_test_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $t | Out-Null
try {
    Set-Content (Join-Path $t 'one.txt') 'first' -Encoding UTF8
    Set-Content (Join-Path $t 'two.txt') 'second' -Encoding UTF8

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Backup.ps1') `
        -Quiet (Join-Path $t 'one.txt') | Out-Null
    $runs = @(Get-ChildItem (Join-Path $t 'Backups') -Directory)
    Check 'backup creates one timestamped folder' ($runs.Count -eq 1)
    Check 'backup keeps the original' (Test-Path (Join-Path $t 'one.txt'))
    Check 'the copy is there' (Test-Path (Join-Path $runs[0].FullName 'one.txt'))
    $log = Get-Content (Join-Path $t 'Backups\backup-log.txt') -Raw
    Check 'the log says 1 item, not 1 items' ($log -match '\(1 (item|objekt)\)') $log

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Backup.ps1') `
        -Move -Quiet (Join-Path $t 'two.txt') | Out-Null
    Check 'archive removes the original' (-not (Test-Path (Join-Path $t 'two.txt')))

    # restore a single item — the case that used to fall through to "nothing to restore"
    Remove-Item (Join-Path $t 'one.txt') -Force
    $env:REPRISE_AUTOSELECT = '1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Restore.ps1') `
        -Quiet (Join-Path $runs[0].FullName 'one.txt') | Out-Null
    Remove-Item Env:\REPRISE_AUTOSELECT -ErrorAction SilentlyContinue
    Check 'a single file restores' (Test-Path (Join-Path $t 'one.txt'))
    Check 'and keeps its content' ((Get-Content (Join-Path $t 'one.txt') -Raw).Trim() -eq 'first')
} finally {
    Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "$pass/$($pass + $fail) passed  (language: $script:RepriseLang)" `
    -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
exit $(if ($fail) { 1 } else { 0 })
