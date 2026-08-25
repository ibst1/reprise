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

^!b::RunTool(BackupPath, "",      T("doneBackup"))
^!m::RunTool(BackupPath, " -Move", T("doneArchive"))
^!r::RunTool(RestorePath, "",      T("doneRestore"))

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
            "items",       " items"),
        "sv", Map(
            "tray",        "Ctrl+Alt+B backup  |  Ctrl+Alt+M arkivera  |  Ctrl+Alt+R återställ",
            "doneBackup",  "Backup klar: ",
            "doneArchive", "Arkiverat: ",
            "doneRestore", "Återställt: ",
            "noSelection", "Inga objekt markerade i Utforskaren",
            "item",        " objekt",
            "items",       " objekt"))
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

Flash(text, ms := 2200) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}
