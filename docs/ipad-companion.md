# SetCatcher for iPad

Last updated: September 1, 2026.

## Product shape

**SetCatcher for iPad** is a **standalone** iPadOS 17+ app (bundle ID `app.setcatcher.SetCatcher.iPad`). iPhone is also supported via a compact tab layout.

There is **no Mac connection**. It does not pair with, mirror, or sync archives from the Mac app. It only works with DJ apps and audio **on this device**.

| On this iPad / iPhone | Not on iOS |
| --- | --- |
| Local library browse / edit | Mac folder Protection |
| Files + Share import (djay first) | Listening to Mac DJ apps (Serato, rekordbox, Traktor, VirtualDJ, …) |
| Parallel **device input** capture while you DJ on this device | ScreenCaptureKit / per-app audio tap of another iOS app (iPadOS does not allow that) |
| Optional account sign-in | Requiring the Mac app to be online |

Honest labels: mobile adapters start **Manual Setup**. Desktop DJ engines are a separate Mac product — they are not “missing” from iPad; they are out of scope here.

## What Mac and iOS share (only this)

**User accounts and account-related information** — one Clerk + Supabase + Vercel stack:

| Layer | Shared |
| --- | --- |
| Clerk | Same publishable key / Native API; register Mac + iPad bundle IDs |
| Supabase | Project `alywaxyxnaxwbbsiaafs` (users, devices, licenses, diagnostics) |
| Vercel | `djmemory-admin` — `/api/devices`, `/api/license`, `/api/diagnostics` |

Both clients resolve the host via [`SetCatcherAccountConfiguration`](../Sources/SetCatcherCore/SetCatcherAccountConfiguration.swift) (`SETCATCHER_ACCOUNT_URL`, default `https://beatrevival.com`).

**Not shared:** local archives, recordings, tracklists, Capture sessions, folder bookmarks, or any live audio path. Local library/import never depends on sign-in.

## Open in Xcode

Two different Xcode entry points. The `.xcodeproj` is iOS only.

### SetCatcher for iPad / iPhone (physical device)

Team `3JYK7Q92SF`, Automatic signing, Apple Development.

```sh
# from repo root (requires xcodegen)
bash scripts/open-ipad-xcode.sh
```

Or:

```sh
xcodegen generate --spec project.yml
open SetCatcher.xcodeproj
```

1. Unlock the iPhone or iPad and keep it awake (a locked device cannot mount the developer disk image).
2. Scheme: **SetCatcheriPad** (Run must launch `SetCatcher.app`, not the Share extension).
3. Destination: the connected device (iOS 17+). An iPhone is valid — the companion uses a compact tab layout. Plug in an iPad when you want to test the iPad layout.
4. Product → Run (`⌘R`). Trust the developer on the device if iOS asks (Settings → General → VPN & Device Management).
5. First Capture needs the microphone prompt; Files/Share import does not.

CLI check (does not install; device must still be unlocked to install):

```sh
xcodebuild -project SetCatcher.xcodeproj -scheme SetCatcheriPad \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=3JYK7Q92SF CODE_SIGN_STYLE=Automatic build
```

Bundle ID: `app.setcatcher.SetCatcher.iPad`

Share extension bundle ID: `app.setcatcher.SetCatcher.iPad.ShareExtension`

App Group (Share → Inbox): `group.app.setcatcher.shared`

### macOS app (this Mac)

```sh
bash scripts/open-xcode.sh
```

That opens `Package.swift`. Scheme: **SetCatcherApp**. Destination: **My Mac**. Product → Run.

Do not pick **SetCatcheriPad** for Mac — that scheme is iOS only.

## Architecture

- Shared [`SetCatcherCore`](../Sources/SetCatcherCore) code (paths, archive helpers, account URL config) — not a runtime link to a Mac.
- UI in [`Sources/SetCatcherCompanion`](../Sources/SetCatcherCompanion).
- Thin `@main` wrapper in [`Apps/SetCatcherCompanion`](../Apps/SetCatcherCompanion).
- Share extension in [`Apps/SetCatcherShareExtension`](../Apps/SetCatcherShareExtension).
- Optional Clerk account (same privacy rules as Mac: no automatic audio upload).
