#Requires AutoHotkey v2.0
; ---------------------------------------------------------------------------
;  Reprise - hotkeys
;    Ctrl+Alt+B  = Backup  (copy to Backups, keep the original)
;    Ctrl+Alt+M  = Archive (move: copy + delete the original after verification)
;    Ctrl+Alt+R  = Restore (put selected items back from a Backups folder)
;
;  Acts on the items selected in the active Explorer window.
;  Change the hotkeys below if needed:  ^ = Ctrl,  ! = Alt,  + = Shift,  # = Win
; ---------------------------------------------------------------------------

; The script knows where it lives — nothing to edit when the folder moves, which
; is exactly what made renaming this tool more work than it should have been.
ToolDir     := A_ScriptDir
BackupPath  := ToolDir "\Backup.ps1"
RestorePath := ToolDir "\Restore.ps1"

; Tray icon in Expanto style
if FileExist(ToolDir "\icons\tray.ico")
    TraySetIcon(ToolDir "\icons\tray.ico")
A_IconTip := "Reprise`n" T("tray")

RepoUrl     := "https://github.com/ibst1/reprise"
HistoryFile := EnvGet("REPRISE_HISTORY") || EnvGet("LOCALAPPDATA") "\Reprise\history.log"
RecentMax   := 10

; ── Tray menu ───────────────────────────────────────────────────────────────
; Our own menu instead of AutoHotkey's. The recent list is rebuilt each time the
; menu opens, because Send To runs write the history without passing through here.
RecentMenu := Menu()
A_TrayMenu.Delete()
A_TrayMenu.Add(T("menuRecent"), RecentMenu)
A_TrayMenu.Add(T("menuRepo"), (*) => Run(RepoUrl))
A_TrayMenu.Add()
A_TrayMenu.Add(T("menuUninstall"), (*) => Uninstall())
A_TrayMenu.Add(T("menuExit"), (*) => ExitApp())
BuildRecent()
OnMessage(0x404, TrayNotify)   ; AHK_NOTIFYICON

TrayNotify(wParam, lParam, *) {
    if ((lParam & 0xFFFF) = 0x205)   ; WM_RBUTTONUP — just before the menu shows
        BuildRecent()
}

; Only in Explorer windows — elsewhere the keys pass through untouched, so
; Ctrl+Alt+M etc. keep working in Word and other programs.
#HotIf WinActive("ahk_class CabinetWClass") || WinActive("ahk_class ExploreWClass")
^!b::RunTool(BackupPath, "",      T("doneBackup"))
^!m::RunTool(BackupPath, " -Move", T("doneArchive"))
^!r::RunTool(RestorePath, "",      T("doneRestore"))
#HotIf

; ── Language ────────────────────────────────────────────────────────────────
; Same rule as the PowerShell engines (Lang.ps1): Reprise.ini decides, and
; "auto" — the default — follows Windows, so the tooltips speak the language the
; message boxes will. The engines cannot share this table, so keep the two in
; step; there are only a handful of strings here.
Lang() {
    global ToolDir
    static lang := ""
    if (lang != "")
        return lang
    v := ""
    try v := StrLower(Trim(IniRead(ToolDir "\Reprise.ini", "Display", "Language", "auto")))
    if (v = "sv" || v = "en")
        return lang := v
    ; LANG_SWEDISH = 0x1D, in the low 10 bits of the UI language id
    ui := DllCall("GetUserDefaultUILanguage", "ushort")
    return lang := ((ui & 0x3FF) = 0x1D) ? "sv" : "en"
}

T(key) {
    static s := Map(
        "en", Map(
            "tray",        "Ctrl+Alt+B backup  |  Ctrl+Alt+M archive  |  Ctrl+Alt+R restore",
            "doneBackup",  "Backup complete: ",
            "doneArchive", "Archived: ",
            "doneRestore", "Restored: ",
            "noSelection", "No items selected in Explorer",
            "item",        " item",
            "items",       " items",
            "menuRecent",  "Most recent backups and moves",
            "menuNone",    "(none yet)",
            "menuLog",     "Open full history",
            "menuRepo",    "GitHub repo",
            "menuUninstall", "Uninstall",
            "menuExit",    "Exit",
            "kindBackup",  "backup",
            "kindArchive", "moved",
            "folderGone",  "The folder no longer exists:`n",
            "uninstallAsk", "Remove Reprise from this computer?`n`nThis removes the Send To entries, the startup shortcut and the history, and quits Reprise.`nYour backups and the Reprise folder are kept.",
            "uninstallDone", "Reprise is uninstalled. The folder is kept:`n"),
        "sv", Map(
            "tray",        "Ctrl+Alt+B backup  |  Ctrl+Alt+M arkivera  |  Ctrl+Alt+R återställ",
            "doneBackup",  "Backup klar: ",
            "doneArchive", "Arkiverat: ",
            "doneRestore", "Återställt: ",
            "noSelection", "Inga objekt markerade i Utforskaren",
            "item",        " objekt",
            "items",       " objekt",
            "menuRecent",  "Senaste backuper och flyttar",
            "menuNone",    "(inga än)",
            "menuLog",     "Öppna hela historiken",
            "menuRepo",    "GitHub-repo",
            "menuUninstall", "Avinstallera",
            "menuExit",    "Avsluta",
            "kindBackup",  "backup",
            "kindArchive", "flyttad",
            "folderGone",  "Mappen finns inte längre:`n",
            "uninstallAsk", "Ta bort Reprise från den här datorn?`n`nSkicka till-posterna, autostartgenvägen och historiken tas bort, och Reprise avslutas.`nDina backuper och Reprise-mappen behålls.",
            "uninstallDone", "Reprise är avinstallerat. Mappen behölls:`n"))
    t := s[Lang()]
    return t.Has(key) ? t[key] : (s["en"].Has(key) ? s["en"][key] : "[" key "]")
}

RunTool(scriptPath, extraSwitch, doneMsg) {
    sel := GetExplorerSelection()
    if (sel.Length = 0) {
        Flash(T("noSelection"))
        return
    }

    args := ""
    for path in sel
        args .= ' "' path '"'

    cmd := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden'
         . ' -File "' scriptPath '"' extraSwitch ' -Quiet' args

    RunWait(cmd, , "Hide")
    Flash(doneMsg sel.Length T(sel.Length = 1 ? "item" : "items"))
}

GetExplorerSelection() {
    paths := []
    hwnd := WinActive("A")
    if !hwnd
        return paths

    winClass := WinGetClass("ahk_id " hwnd)
    if !(winClass ~= "i)^(CabinetWClass|ExploreWClass)$")
        return paths

    for window in ComObject("Shell.Application").Windows {
        try {
            if (window.HWND = hwnd) {
                for item in window.Document.SelectedItems
                    paths.Push(item.Path)
            }
        }
    }
    return paths
}

; History lines: timestamp <tab> BACKUP|ARCHIVE <tab> destination <tab> name|name…
BuildRecent() {
    global RecentMenu, HistoryFile, RecentMax
    RecentMenu.Delete()
    lines := []
    try {
        for line in StrSplit(FileRead(HistoryFile, "UTF-8"), "`n", "`r")
            if (line != "")
                lines.Push(line)
    }
    n := 0
    i := lines.Length
    while (i >= 1 && n < RecentMax) {
        f := StrSplit(lines[i--], "`t")
        if (f.Length < 4)
            continue
        n++
        names := StrSplit(f[4], "|")
        what := names[1] (names.Length > 1 ? "  (+" (names.Length - 1) ")" : "")
        when := RegExReplace(f[1], "^(\d{4}-\d\d-\d\d)_(\d\d)(\d\d)\d\d$", "$1 $2:$3")
        kind := T(f[2] = "ARCHIVE" ? "kindArchive" : "kindBackup")
        ; "&n" gives each entry a unique name and a keyboard accelerator
        RecentMenu.Add("&" Mod(n, 10) "  " what "`t" kind "  " when, OpenFolder.Bind(f[3]))
    }
    if (n = 0) {
        RecentMenu.Add(T("menuNone"), (*) => 0)
        RecentMenu.Disable(T("menuNone"))
    } else {
        RecentMenu.Add()
        RecentMenu.Add(T("menuLog"), (*) => Run('notepad.exe "' HistoryFile '"'))
    }
}

OpenFolder(path, *) {
    if DirExist(path)
        Run('explorer.exe "' path '"')
    else
        MsgBox(T("folderGone") path, "Reprise", "Icon!")
}

Uninstall() {
    global ToolDir
    if (MsgBox(T("uninstallAsk"), "Reprise", "YesNo Icon? Default2") != "Yes")
        return
    RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'
          . ToolDir '\Uninstall.ps1" -Quiet', , "Hide")
    MsgBox(T("uninstallDone") ToolDir, "Reprise", "Iconi")
    ExitApp()
}

Flash(text, ms := 2200) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}
