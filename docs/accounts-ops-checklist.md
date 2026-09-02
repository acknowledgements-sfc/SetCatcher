# Accounts deploy ops checklist (repo-side)

Last updated: September 2, 2026.

This tracks what the repo can verify. Secrets never belong in git.

Clerk is **identity only**. Do not enable Clerk Billing, Organizations, or Clerk Waitlist — licenses, devices, invites, and catalog stay in Supabase.

| Step | Status |
| --- | --- |
| Supabase project + `001_initial.sql` | Done |
| Client routes `/api/devices`, `/api/license`, `/api/diagnostics` | Done |
| Clerk middleware matcher includes `/__clerk` + API | Done (`admin/src/middleware.ts`) |
| Native Bearer session JWT → `requireSignedIn` + Backend email fallback | Done (`admin/src/lib/auth.ts`, `clerk-user.ts`) — **verified locally 2026-09-02**: session JWT `GET /api/license` 200 + `POST /api/devices` 200, real email (not `@users.clerk.local`), `archiveScanProtect: true`, unsigned license 401 |
| Document Mac + iPad Native API bundle IDs | Done (`docs/accounts-deploy.md`) |
| `admin/.env.local` Clerk keys | Present (dev `pk_test_` until Production switch) |
| Vercel project linked | Done — `acknowledgements-sfcs-projects/djmemory-admin` (`prj_G8oOgEBzVlweAXQRYYp8tq8praQu`) |
| Vercel production env (Clerk + Supabase URL + account URL) | Pushed |
| `admin/.env.local` `SUPABASE_SERVICE_ROLE_KEY` | Done (2026-08-09) |
| Vercel `SUPABASE_SERVICE_ROLE_KEY` | Done + production redeployed |
| Shared client account URL | Done — `SetCatcherAccountConfiguration` default `https://beatrevival.com` (`SETCATCHER_ACCOUNT_URL`) |
| Vercel custom domains | Done — `beatrevival.com` + `www.beatrevival.com` on `djmemory-admin` (also `setcatcher.com`) |
| Hover DNS → Vercel | Done (2026-08-09) — A `@` → `76.76.21.21`, CNAME `www` → `cname.vercel-dns.com`; `https://beatrevival.com/admin` live |
| Marketing + `POST /api/waitlist` | Done |
| `npx vercel --prod` | Deployed 2026-09-02 `dpl_EoaWUd8tYZJ3aDJ2SGD25Z97WS5c` (Bearer JWT + email fallback). Aliased `setcatcher.com`. Verified `GET /api/license` 200 with session JWT on beatrevival.com and setcatcher.com; unsigned 401; real email; `archiveScanProtect: true` |
| Clerk Native API for Mac + iPad | **Done 2026-09-01.** Native API on (dev+prod). Team `3JYK7Q92SF` + `app.setcatcher.SetCatcher` + `app.setcatcher.SetCatcher.iPad` on both instances. Callbacks allowlisted. Dev AASA lists both SetCatcher apps. |
| `admin_roles` owner row | **Verified** `user_…` (32 chars) for `yo@rcawhatsgood.com` matches Clerk dev user `user_3Hh8gN3pA2nS5Uy3DFQCoSQCo4T` |
| Clerk Production + allowlist hosts | **Human — you do next** (Hobby OK; MFA needs Clerk Pro — skip until Pro) |
| Associated Domains production Frontend API host | **Human — after Production custom domain**; today both apps use `webcredentials:glorious-longhorn-36.clerk.accounts.dev` |

## You do next (Dashboard — this agent cannot click Clerk)

### 1. Clerk Native API (Mac + iPad)

1. Open [Native applications](https://dashboard.clerk.com/~/native-applications).
2. Enable **Native API** if not already on.
3. Register two apps (Team ID / App ID Prefix `3JYK7Q92SF`):

| App | Bundle ID | Redirect |
| --- | --- | --- |
| macOS | `app.setcatcher.SetCatcher` | `app.setcatcher.SetCatcher://callback` |
| iPad | `app.setcatcher.SetCatcher.iPad` | `app.setcatcher.SetCatcher.iPad://callback` |

Also allowlist those redirect URLs under Paths / OAuth as shown in the Dashboard.

**Agent 2026-09-01 night:** Native API toggle on for DJMemory **development** and **production**. Dashboard iOS apps now include `3JYK7Q92SF` + `app.setcatcher.SetCatcher` and `app.setcatcher.SetCatcher.iPad` on both instances (legacy `app.djmemory.*` rows remain). Dev AASA `webcredentials.apps` includes both SetCatcher IDs. Callbacks allowlisted. `admin_roles` matches Clerk dev `user_…`. Live Bearer `GET /api/license` on beatrevival.com still 200 + `archiveScanProtect: true`. Glass: Settings is open and local archive shows 4 sets while Ready/not armed (signed out). Sign in is blocked on the login-keychain prompt for `app.setcatcher.SetCatcher` — this agent will not enter that password. Billing and Organizations were not enabled.

Native env/plist key: `SETCATCHER_CLERK_PUBLISHABLE_KEY` (same value as `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`).

### 2. Admin owner row (verify)

Inserted 2026-08-09 for `yo@rcawhatsgood.com` as `owner`.

**Check:** Clerk session `userId` must match `admin_roles.clerk_user_id` exactly. If the row still uses `rcatestgood` (not a real `user_…` id), `/admin` returns Forbidden. Fix: Dashboard → Users → user → **User ID**, then update the row.

### 3. Clerk Production for beatrevival.com / setcatcher.com

1. Dashboard → **DJMemory** (or SetCatcher instance) → **Production**.
2. Allowlist origins/redirects: `https://beatrevival.com`, `https://www.beatrevival.com`, `https://setcatcher.com`, `https://www.setcatcher.com`, `https://djmemory-admin.vercel.app`, `http://localhost:3000`, plus the native callbacks above.
3. Put Production `pk_` / `sk_` into Vercel env + `admin/.env.local`, then `npx vercel --prod`.
4. Optional (Clerk Pro ~$25/mo): enforce MFA for admin users.
5. After production Frontend API host is known, update Associated Domains in [`packaging/SetCatcher.entitlements`](../packaging/SetCatcher.entitlements) and [`Apps/SetCatcherCompanion/SetCatcherCompanion.entitlements`](../Apps/SetCatcherCompanion/SetCatcherCompanion.entitlements).

Production host is live: `https://beatrevival.com`. Fallback: `https://djmemory-admin.vercel.app`.

### Service role (already done)

`SUPABASE_SERVICE_ROLE_KEY` is set in `admin/.env.local` and Vercel production. Re-run only if rotating the key:

```sh
bash scripts/fill-supabase-service-role-from-clipboard.sh
bash scripts/push-accounts-vercel-env.sh
cd admin && npx vercel --prod
```
