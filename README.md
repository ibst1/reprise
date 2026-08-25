# Reprise – timestamped backup, archiving & restore

*A reprise is a return to an earlier passage – and that is what this tool does: it
brings an earlier version of a file back.*

Copies selected files/folders to a `Backups` subfolder in the same folder, in a run
folder of its own with a timestamp. File extensions and original names are preserved,
so the copies can be opened directly. Every run always produces a new copy (nothing is
overwritten).

**Result:** `...\Backups\2026-07-28_143502\originalname.ext`

Three actions:

| Action | What it does |
|----------|-------------|
| **Backup** | Copies the selected items to `Backups\<timestamp>\`. The original stays where it is. |
| **Archive** | Like Backup, but **deletes the original** afterwards – only once the copy has been verified byte for byte (size + file count). If verification fails the original is kept. |
| **Restore** | Puts the selected items back from a `Backups` folder to their original location. |

All files live in one folder — put it wherever you like, the scripts find
themselves from there:

| File | Role |
|-----|------|
| `Backup.ps1` | The engine for Backup and Archive (`-Move`). |
| `Restore.ps1` | The restore engine. |
| `Install-SendTo.ps1` | Run once – puts the three entries in your SendTo menu. |
| `Reprise.ahk` | AutoHotkey v2 – hotkeys (see below). |

---

## Entry point 1 – Right-click menu (Send To)

Already installed. Select items in Explorer, right-click → **Send To** →

- **Backup (timestamped)**
- **Archive (move + timestamp)**
- **Restore from backup**

A small box confirms the result (it closes itself after a few seconds).

> On Windows 11: "Send To" sits under **Show more options** in the new right-click
> menu (or press **Shift+F10** for the classic menu directly).

Reinstall/update the entries (e.g. if you move the folder):
```
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-SendTo.ps1
```

## Entry point 2 – Hotkeys (AutoHotkey)

Double-click `Reprise.ahk` once (icon in the system tray), select items in an Explorer
window and press:

| Hotkey | Action |
|--------------|----------|
| **Ctrl+Alt+B** | Backup (copy) |
| **Ctrl+Alt+M** | Archive (move) |
| **Ctrl+Alt+R** | Restore |

A tooltip shows how many items were processed.

**Start automatically at logon:** Win+R → `shell:startup` → Enter, put a shortcut to
`Reprise.ahk` there. Change a hotkey by editing the lines `^!b::`, `^!m::`, `^!r::` at
the top of the file (`^`=Ctrl, `!`=Alt, `+`=Shift, `#`=Win).

---

## How Restore works

- Select **individual items** inside a `Backups\<timestamp>\` folder, or select the
  **whole timestamp folder** to restore everything in it.
- Each item is put back in its original relative location.
- **If the target already exists** the script asks once:
  *Yes* = overwrite · *No* = skip the ones that collide · *Cancel* = cancel everything.

## If something doesn't work

- **"Send To" does nothing / a window flashes past:** run the engine manually to see the error:
  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Backup.ps1 "C:\path\to\testfile.txt"
  ```
- **Blocked by the execution policy:** the calls already use `-ExecutionPolicy Bypass`.
  If your workplace enforces a stricter policy through group policy (GPO), Bypass may be
  ignored – let me know and I'll make a variant that runs as an encoded command instead
  of a script file.
- **Every `Backups` folder has a `backup-log.txt`** with one line per run, tagged
  `[BACKUP]` or `[ARCHIVE]`.

## Language

Reprise speaks Swedish and English. It follows Windows by default, which also keeps
the wording in step with the buttons: Windows always captions a message box in its own
language, so English text above **Ja / Nej / Avbryt** would leave you translating in
your head. Set it explicitly in `Reprise.ini` next to the scripts:

```ini
[Display]
Language=auto    ; auto = follow Windows · sv = always Swedish · en = always English
```

Every string lives once, in `Lang.ps1`, with both languages side by side — so a string
cannot exist in one language and be missing in the other. `Reprise.ahk` keeps its own
small table, because AutoHotkey cannot read a PowerShell file. `Test-Reprise.ps1`
checks that the two languages hold the same keys, that every key the scripts ask for
exists, and that backup, archive and restore still work.

After switching language, re-run `Install-SendTo.ps1` — the Send To entries take their
names from the same table, and Windows stores those names as filenames.

**A file with å/ä/ö in it must be saved as UTF-8 with a BOM.** Windows PowerShell 5.1
and AutoHotkey both read a BOM-less file as ANSI, and the Swedish then arrives as
`tidsstÃ¤mplad` — which ends up in the Send To entry names, on disk. The test suite
checks this, because it is silent when it goes wrong.

## Uninstall

- Remove the menu entries: Win+R → `shell:sendto` → delete the three `Backup`/`Archive`/`Restore` shortcuts.
- Quit AHK: right-click the icon in the system tray → Exit (and remove any shortcut in `shell:startup`).
- Delete the whole `Reprise` folder.
