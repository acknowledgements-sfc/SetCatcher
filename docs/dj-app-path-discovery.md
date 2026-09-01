# DJ app path discovery

Last updated: September 1, 2026.

SetCatcher resolves DJ-app folder locations for **folder protection and history ingest** using this precedence:

1. **User preference** — readable prefs/config from the installed app (when verified).
2. **Catalog default** — documented defaults in [`DJSoftware.swift`](../Sources/SetCatcherCore/DJSoftware.swift).
3. **Filesystem probe** — reserved for future use; not claimed without evidence.

Discovered paths are **hints only**. SetCatcher never scans a folder until the DJ grants it via a security-scoped bookmark.

All preference reads resolve against the **current user's home directory** (`~/Library/Preferences/<bundleID>.plist`, `~/Library/Application Support/...`). Another macOS user account on the same machine has separate prefs; SetCatcher only reads the account running the app or CLI.

## Per-app notes

| Family | Preference source | Known keys | Confidence |
| --- | --- | --- | --- |
| Serato | `~/Library/Preferences/com.serato.seratodj.plist` (or `com.serato.dj` for Lite) | `record_location` (bench-confirmed; per macOS user account) | High for recordings |
| rekordbox | `~/Library/Preferences/com.pioneerdj.rekordboxdj.plist` + Application Support | `recordingPath` / `recordPath` when present | Low — rekordbox 7 had no recording path in prefs on test Mac |
| Traktor | `~/Documents/Native Instruments/Traktor */` | `MixRecorder.Path` in settings when present | Medium |
| VirtualDJ | `~/Documents/VirtualDJ/settings.xml` | `recordFolder`, `record`, `recordingFolder` | Medium |
| djay | App container + `~/Music/djay*` | `recordingPath` when present in container docs | Low |
| Engine DJ (desktop) | `~/Library/Application Support/Engine DJ` (and aliases) | `recordingPath` / `recordPath` when present | Low — no bench Mac yet; **Manual Setup** |
| Denon Hardware | N/A (USB/SD) | User picks `Sessions` folder | Manual Setup |

## Variant labels

Installed `.app` bundles are mapped to user-visible edition names (e.g. Serato DJ Lite 4, rekordbox 7, djay Pro 2) via [`DJSoftwareVariantCatalog.swift`](../Sources/SetCatcherCore/DJAppPaths/DJSoftwareVariantCatalog.swift).

- Folder grants remain **per family** (`serato`, `rekordbox`, …), not per edition.
- Traktor Pro builds older than 3.8.0 are excluded from installation rows (configurable floor).

## UNKNOWN behavior

When prefs cannot be read or keys are missing:

- UI shows catalog defaults that exist on disk, plus **Choose folder**.
- Support status is **not** upgraded.
- CLI `setcatcher probe` prints discovered paths with `[userPreference|catalogDefault|filesystemProbe]` sources.

## Related

- Capture archives always go to the SetCatcher archive root — not into DJ app recording folders.
- Engine OS USB `Sessions` watch remains `denon-hardware`, separate from desktop `denon-engine`.
