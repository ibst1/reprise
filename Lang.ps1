<#
.SYNOPSIS
    Language for every user-visible string in Reprise. Dot-sourced by the engines.

.DESCRIPTION
    One table for both languages, in one file, so a string can never exist in Swedish
    without its English twin — the failure mode you get when each script carries its
    own copy. Reprise.ahk keeps a small table of its own (it cannot dot-source a
    PowerShell file), and Test-RepriseStrings.ps1 checks that both languages hold the
    same set of keys.

    The language is resolved once, in this order:
      1. Language= under [Display] in Reprise.ini next to this file ("sv" or "en")
      2. the Windows UI language, when that setting is missing or says "auto"
      3. English

    Following Windows by default is what keeps the message text and the message BOX
    in the same language: a Swedish Windows captions its buttons Ja / Nej / Avbryt,
    and English text above those buttons made the user translate in their head.
#>

function Get-RepriseLanguage {
    $ini = Join-Path $PSScriptRoot 'Reprise.ini'
    if (Test-Path -LiteralPath $ini) {
        foreach ($line in Get-Content -LiteralPath $ini -ErrorAction SilentlyContinue) {
            if ($line -match '^\s*Language\s*=\s*(\w+)') {
                $v = $Matches[1].ToLower()
                if ($v -eq 'sv' -or $v -eq 'en') { return $v }
                break   # "auto" or anything else: fall through to the OS
            }
        }
    }
    if ((Get-UICulture).TwoLetterISOLanguageName -eq 'sv') { return 'sv' }
    return 'en'
}

$script:RepriseLang = Get-RepriseLanguage

$script:RepriseStrings = @{
    en = @{
        # Backup.ps1
        'backup.noPaths'      = "No files or folders were given.`n`nSelect items and run via 'Send To -> Backup' or the hotkey."
        'backup.noValid'      = 'Found no valid paths to copy.'
        'backup.titleBackup'  = 'Backup'
        'backup.titleArchive' = 'Archiving'
        'backup.doneBackup'   = 'Backup complete'
        'backup.doneArchive'  = 'Archiving complete'
        'backup.copiedTo'     = "{0} {1} copied to:`n{2}"
        'backup.movedTo'      = "{0} {1} copied, {2} {3} deleted.`n`nTo:`n{4}"
        'backup.withErrors'   = "{0} finished with errors.`n`nCopied: {1} {2}"
        'backup.item'         = 'item'
        'backup.items'        = 'items'
        'backup.original'     = 'original'
        'backup.originals'    = 'originals'

        # Restore.ps1
        'restore.collision'   = "{0} {1} already exist at the original location.`n`n"
        'restore.collYes'     = "Yes    = overwrite`n"
        'restore.collNo'      = "No     = skip the ones that collide`n"
        'restore.collCancel'  = 'Cancel = cancel everything'
        'restore.collTitle'   = 'Restore'
        'restore.noItems'     = "No items were given.`n`nSelect either items inside a Backups folder, or a file/folder in the main folder that has earlier versions."
        'restore.nothing'     = "Found nothing to restore.`n`nSelected items must either live under a "
        'restore.pickTitle'   = 'Restore: {0}'
        'restore.pickLabel'   = 'Choose which version to restore (overwrites the current one):'
        'restore.pickOk'      = 'Restore'
        'restore.pickCancel'  = 'Cancel'
        'restore.failed'      = "Could not restore: {0}`n{1}"
        'restore.withErrors'  = "Restore completed with errors.`n`nRestored: {0}   Skipped: {1}`n`nErrors:`n"
        'restore.done'        = 'Restore complete'
        'restore.nItems'      = '{0} items'

        # Install-SendTo.ps1
        'install.created'     = 'Created: {0}'
        'install.done'        = 'Done. Right-click a file/folder -> Send To -> the entry you want.'
        'sendto.backup'       = 'Backup (timestamped)'
        'sendto.archive'      = 'Archive (move + timestamp)'
        'sendto.restore'      = 'Restore from backup'
        'sendto.backupDesc'   = 'Copy the selected items to a timestamped Backups folder'
        'sendto.archiveDesc'  = 'Copy to a timestamped Backups folder, then delete the originals'
        'sendto.restoreDesc'  = 'Put items back from a Backups folder'

        # Uninstall.ps1
        'uninstall.removed'   = 'Removed: {0}'
        'uninstall.nothing'   = 'Nothing of Reprise was installed here.'
        'uninstall.kept'      = 'The folder {0} was kept - delete it yourself if you no longer want it.'
    }
    sv = @{
        # Backup.ps1
        'backup.noPaths'      = "Inga filer eller mappar angavs.`n`nMarkera objekt och kör via 'Skicka till -> Backup' eller kortkommandot."
        'backup.noValid'      = 'Hittade inga giltiga sökvägar att kopiera.'
        'backup.titleBackup'  = 'Backup'
        'backup.titleArchive' = 'Arkivering'
        'backup.doneBackup'   = 'Backup klar'
        'backup.doneArchive'  = 'Arkivering klar'
        'backup.copiedTo'     = "{0} {1} kopierade till:`n{2}"
        'backup.movedTo'      = "{0} {1} kopierade, {2} {3} borttagna.`n`nTill:`n{4}"
        'backup.withErrors'   = "{0} slutfördes med fel.`n`nKopierade: {1} {2}"
        'backup.item'         = 'objekt'
        'backup.items'        = 'objekt'
        'backup.original'     = 'original'
        'backup.originals'    = 'original'

        # Restore.ps1
        'restore.collision'   = "{0} {1} finns redan på ursprungsplatsen.`n`n"
        'restore.collYes'     = "Ja     = skriv över`n"
        'restore.collNo'      = "Nej    = hoppa över de som krockar`n"
        'restore.collCancel'  = 'Avbryt = avbryt allt'
        'restore.collTitle'   = 'Återställ'
        'restore.noItems'     = "Inga objekt angavs.`n`nMarkera antingen objekt inuti en Backups-mapp, eller en fil/mapp i huvudmappen som har tidigare versioner."
        'restore.nothing'     = "Hittade inget att återställa.`n`nMarkerade objekt måste antingen ligga under en "
        'restore.pickTitle'   = 'Återställ: {0}'
        'restore.pickLabel'   = 'Välj vilken version som ska återställas (skriver över den nuvarande):'
        'restore.pickOk'      = 'Återställ'
        'restore.pickCancel'  = 'Avbryt'
        'restore.failed'      = "Kunde inte återställa: {0}`n{1}"
        'restore.withErrors'  = "Återställningen slutfördes med fel.`n`nÅterställda: {0}   Överhoppade: {1}`n`nFel:`n"
        'restore.done'        = 'Återställning klar'
        'restore.nItems'      = '{0} objekt'

        # Install-SendTo.ps1
        'install.created'     = 'Skapad: {0}'
        'install.done'        = 'Klart. Högerklicka på en fil/mapp -> Skicka till -> den post du vill ha.'
        'sendto.backup'       = 'Backup (tidsstämplad)'
        'sendto.archive'      = 'Arkivera (flytta + tidsstämpel)'
        'sendto.restore'      = 'Återställ från backup'
        'sendto.backupDesc'   = 'Kopiera markerade objekt till en tidsstämplad Backups-mapp'
        'sendto.archiveDesc'  = 'Kopiera till en tidsstämplad Backups-mapp och ta sedan bort originalen'
        'sendto.restoreDesc'  = 'Lägg tillbaka objekt från en Backups-mapp'

        # Uninstall.ps1
        'uninstall.removed'   = 'Borttagen: {0}'
        'uninstall.nothing'   = 'Inget av Reprise var installerat här.'
        'uninstall.kept'      = 'Mappen {0} behölls - ta bort den själv om du inte längre vill ha den.'
    }
}

function T {
    <#
    .SYNOPSIS
        The string for $Key in the resolved language, with {0}, {1}… filled in.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(ValueFromRemainingArguments = $true)][object[]]$Args
    )
    $table = $script:RepriseStrings[$script:RepriseLang]
    if (-not $table.ContainsKey($Key)) {
        # Never hide a missing key behind an empty message box: show the key.
        $table = $script:RepriseStrings['en']
        if (-not $table.ContainsKey($Key)) { return "[$Key]" }
    }
    $s = $table[$Key]
    if ($Args -and $Args.Count) { return ($s -f $Args) }
    return $s
}

function T-Plural {
    <#
    .SYNOPSIS
        Singular or plural form for a count. Swedish "1 objekt / 5 objekt" does not
        inflect, English "1 item / 5 items" does — so this belongs in the table, not
        in an "s" appended at the call site.
    #>
    param([int]$Count, [string]$SingularKey, [string]$PluralKey)
    if ($Count -eq 1) { return (T $SingularKey) }
    return (T $PluralKey)
}
