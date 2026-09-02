# DJMemory Accounts API

Last updated: August 9, 2026.

Authority: [`docs/onboarding-accounts-security.md`](onboarding-accounts-security.md).

The macOS (and future iPad) app stays fully usable without sign-in. This API backs optional licensing, beta invites, device registration, and opt-in diagnostics metadata. It must never become a dependency of local archive/scan/protection paths.

## Base URL

- Local: `http://localhost:3000`
- Production: `https://beatrevival.com` (Vercel project `djmemory-admin`; also `NEXT_PUBLIC_ACCOUNT_URL` / client `DJMEMORY_ACCOUNT_URL`; Mac and iPad share [`DJMemoryAccountConfiguration`](../Sources/DJMemoryCore/DJMemoryAccountConfiguration.swift)). Fallback: `https://djmemory-admin.vercel.app` until DNS is live.

## Privacy boundaries

| Data | Default |
| --- | --- |
| Audio files | Never uploaded |
| Full tracklists / titles / artists | Never uploaded by default; not accepted in diagnostics metadata |
| Diagnostics | Opt-in; metadata only (counts, paths, timings, error strings) |
| Admin access | No audio playback/download; no tracklist contents |

## Public

### `GET /api/health`

Returns service health and privacy posture. No auth.

### `POST /api/waitlist`

Public beta waitlist signup. No auth.

Body: `{ "email" }`

Inserts a `beta_invites` row with `status: pending` and `created_by_clerk_id: null` (shown as **Waitlist** in `/admin/invites`). Duplicate pending emails return `{ ok: true, alreadyListed: true }`.

## Signed-in client contract (Clerk session JWT)

Optional after sign-in. Do not call from archive/scan/protection paths. Offline or unreachable = full local features.

macOS Settings → Account uses ClerkKit `AuthView` / `UserButton`, then calls these endpoints with `Authorization: Bearer <session token>`.

### `POST /api/devices`

Register or refresh a device.

Body: `{ "deviceName", "appVersion?", "installChannel?", "platformDeviceId?" }`

Creates a `users` row (and free license) on first sight. Upserts by user + stable device name (includes `platformDeviceId` when provided).

On first `users` insert, any matching `beta_invites` rows for that email with `status: pending` are marked `accepted` (`accepted_at` set) and an `invites.accept` audit event is written. Waitlist and admin-created invites both count.

### `GET /api/license`

Returns user + active license snapshot and an explicit `localFeatures.archiveScanProtect: true` note. Cache locally; when unreachable, clients keep full local features.

### `POST /api/diagnostics`

User-initiated metadata-only upload. Body: `{ "metadata": { … } }`.

Rejects top-level `title`, `artist`, `tracks`, and `tracklist` keys. Nested forbidden keys are stripped server-side.

### `GET /api/archive/sessions`

Pull archive catalog metadata for the signed-in user (no audio, no tracklists).

Query: `updatedSince` (ISO8601, optional)

Returns `{ sessions: [...], restrictions }`. Each session includes metadata fields and optional `setContext` (event/venue/city/tags/notes only).

### `POST /api/archive/sessions`

Upsert catalog rows from this device.

Body: `{ "sessions": [ { "sessionId", "platform" ("macos"|"ios"), "sourceAppId", "detectedAt", "originalFilename", ... , "setContext"? } ] }`

Rejects `sourcePath`, `archivePath`, `tracklist`, `tracks`, `title`, `artist`, and `manualTracklistID`.

### `DELETE /api/archive/sessions/:sessionId`

Soft-delete a catalog row for this user.

## Admin (Clerk session + `admin_roles` row)

All admin routes require a signed-in Clerk user with a matching `admin_roles` row. Mutations require `owner`, `support`, or `release_manager` (`read_only` is view-only). Invite management: `owner`, `release_manager`, or `support`.

Every successful admin call writes an `admin_audit_events` row.

### `GET /api/admin/users?email=`

Search users by email substring (max 50).

### `PATCH /api/admin/users`

Body: `{ "userId", "status?", "releaseChannel?" }`

### `GET /api/admin/users/detail?userId=`

Returns devices, licenses, and diagnostics metadata for one user. Response includes an explicit `restrictions` object stating audio/tracklist denial.

### `GET /api/admin/invites`

List beta invites.

### `POST /api/admin/invites`

Body: `{ "email" }` to create, or `{ "resendId" }` to bump `sent_at` / keep `pending`.

Does **not** send email yet. Responses include `emailDelivery: "not_sent"` so the admin UI stays honest.

### `POST /api/admin/revoke`

Body: `{ "action": "revoke_device"|"revoke_license", "deviceId"|"licenseId" }`

### `GET /api/admin/audit`

Recent audit events (max 200).

## Roles

| Role | Capabilities |
| --- | --- |
| owner | Full admin |
| support | User lookup, invites, revoke, diagnostics metadata |
| release_manager | Invites, release channel |
| read_only | Lookup and audit view without mutation |
