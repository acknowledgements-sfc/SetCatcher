# Handoff → chat `82823707-6da5-4db2-96ef-032c5d169e92`

**From:** [iPad and iOS builds](0c3e3c92-ae83-4781-95a9-a0167e0bc4ab) (closing)  
**To:** [SetCatcher development tasks](82823707-6da5-4db2-96ef-032c5d169e92) (canonical)  
**Branch:** `feature/dual-lane-archive-phase-a` (synced with `origin`)  
**Date:** 2026-09-02

Rob asked to consolidate all remaining work into the development-tasks chat. This chat is done; pick up below.

---

## Already landed (do not redo)

All pushed on `feature/dual-lane-archive-phase-a`:

| Commit | What |
|--------|------|
| `fcdefb5` | Dual-lane Phase B — Library/Home use `djAppID`; Capture micro-label |
| `e562241` | iPad companion MVP — App Group, Share inbox, Core iOS compile fixes, `SetCatcheriPad` scheme |
| `ee6d587` | Phase A archive catalog sync — Core client/merger, admin API, Mac + iPad hooks |
| `81fda72` | Deploy docs — Supabase restore caveat, catalog API URLs |
| `f45d42d` | **Bearer API fix** — middleware skips `auth.protect()` on `/api/*` so Mac/iPad JWT auth works |

**Verified:** `swift test` green; `SetCatcherApp` macOS + `SetCatcheriPad` generic iOS **BUILD SUCCEEDED**.

**Deployed:** Vercel production (`setcatcher.com` / `beatrevival.com`) includes `/api/archive/sessions`.

**Supabase:** Project was **INACTIVE**, restored, migrations **001–003** reapplied on empty DB. **All prior users/devices/admin_roles are gone** — re-insert `admin_roles` if `/admin` fails.

---

## You already own (keep going here)

From your chat state at handoff:

- Physical device install/launch — Rob's iPhone has SetCatcher open; James's iPad needs Developer Mode + install
- Signing/scheme — `DEVELOPMENT_TEAM: 3JYK7Q92SF` in `project.yml` (may still have uncommitted local tweaks; check `git status`)
- `bash scripts/open-ipad-xcode.sh` runbook in `docs/ipad-companion.md`

**Do not fight this handoff on device QA** — stay in `82823707` for iPhone/iPad install and on-device testing.

---

## Remaining work (pick up in `82823707`)

### 1. Device QA (highest priority)

- [ ] Finish iPad install after Developer Mode on James's iPad
- [ ] Commit any uncommitted signing/scheme/docs from your session if still dirty
- [ ] Manual pass: Import, Share extension, Capture on hardware
- [ ] Sign in on iPhone → **Refresh Account** → confirm license line

### 2. Catalog sync E2E (now unblocked by `f45d42d`)

- [ ] Mac: Settings → Account sign-in → enable **Cloud sync**
- [ ] Archive a set or save set details → confirm push (no audio uploaded)
- [ ] Other device: sign in → refresh → see remote-only row (“On another device…”)
- [ ] Confirm `GET /api/archive/sessions` returns 401 JSON (not 404 HTML) when unsigned

### 3. Ops one-time

- [ ] Re-insert `admin_roles` for Rob in Supabase SQL editor if admin broken
- [ ] Apple Developer: App Group `group.app.setcatcher.shared`; Clerk Native API for `app.setcatcher.SetCatcher.iPad` if not done

### 4. Branch / ship

- [ ] Open PR `feature/dual-lane-archive-phase-a` → `main` when device + sync QA pass
- [ ] **Phase B audio backup** (R2, `cloudArchiveBackupEnabled`) — explicitly **deferred**

### 5. Skip

- `docs/phase2-new-chat-seed.md` — untracked, unrelated; do not commit unless Rob asks

---

## Paste into `82823707` to resume

```
Consolidating from closed chat 0c3e3c92-ae83-4781-95a9-a0167e0bc4ab.

Read docs/handoff-consolidate-to-82823707.md on branch feature/dual-lane-archive-phase-a.

Picked up by: 82823707-6da5-4db2-96ef-032c5d169e92

Continue: (1) iPad install + device QA you already started, (2) catalog sync E2E now that Bearer API fix f45d42d is deployed, (3) PR when QA passes. Do not redo commits e562241–f45d42d.
```

---

## File ownership (collision-safe)

| Area | Owner chat |
|------|------------|
| Companion, Share, Capture on iOS | `82823707` (device + QA) |
| `ArchiveCatalogSync.swift`, admin `/api/archive/*` | landed — extend only if sync QA fails |
| `AppModel` catalog hooks | landed in `ee6d587` — don't revert |
| Live audio / capture acceptance | separate chat `d71f499a` if still dirty |
