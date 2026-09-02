# Deploy DJMemory Accounts (Clerk + Supabase + Vercel)

Last updated: September 2, 2026.

## Status (2026-09-02)

- Supabase project **DJMemory** (`alywaxyxnaxwbbsiaafs`, `us-west-1`). Was **INACTIVE**; restored 2026-09-02 and migrations **001–003** reapplied (see note below).
- Migration `archive_catalog` applied: `archive_sessions`, `archive_set_contexts` (metadata + set context only).
- Catalog API live: `GET/POST /api/archive/sessions`, `DELETE /api/archive/sessions/:sessionId` (see [`accounts-api.md`](accounts-api.md)).
- Production deploy **2026-09-02** includes archive routes (`djmemory-admin` → `beatrevival.com`, `setcatcher.com`).

**Restore caveat:** waking a paused Supabase project can yield an empty database. After restore, re-run migrations 001–003 and re-insert your `admin_roles` row if admin sign-in fails.

## Status (2026-08-09)

- Supabase project **DJMemory** created in Cadence org (`alywaxyxnaxwbbsiaafs`, `us-west-1`).
- URL: `https://alywaxyxnaxwbbsiaafs.supabase.co`
- Migration `initial_accounts_schema` applied (users, devices, licenses, beta_invites, diagnostic_uploads, admin_roles, admin_audit_events + RLS).
- Client contract implemented: `POST /api/devices`, `GET /api/license`, `POST /api/diagnostics` (see [`accounts-api.md`](accounts-api.md)).
- Public waitlist: `POST /api/waitlist` → `beta_invites` (manage at `/admin/invites`).
- Marketing + waitlist UI at `/`; admin at `/admin`.
- macOS Settings Account wires Clerk session → device register, license refresh, optional diagnostics upload.
- Vercel project **djmemory-admin** linked on team `acknowledgements-sfcs-projects`.
- Custom domains **live**: `beatrevival.com` + `www.beatrevival.com` (Hover DNS A/CNAME verified 2026-08-09; see §4a).
- Helpers: [`scripts/fill-supabase-service-role-from-clipboard.sh`](../scripts/fill-supabase-service-role-from-clipboard.sh), [`scripts/push-accounts-vercel-env.sh`](../scripts/push-accounts-vercel-env.sh). See [`accounts-ops-checklist.md`](accounts-ops-checklist.md).

## Public URL map

| URL | Purpose |
| --- | --- |
| `https://beatrevival.com/` | Marketing + beta waitlist |
| `https://beatrevival.com/admin` | Support admin (Clerk + `admin_roles`) |
| `https://beatrevival.com/sign-in` | Clerk sign-in |
| `https://beatrevival.com/api/health` | Health |
| `https://beatrevival.com/api/waitlist` | Public waitlist signup |
| `https://beatrevival.com/api/devices` | Device register (auth) |
| `https://beatrevival.com/api/license` | License snapshot (auth) |
| `https://beatrevival.com/api/diagnostics` | Diagnostics metadata (auth) |
| `https://beatrevival.com/api/archive/sessions` | Archive catalog pull/push (auth; metadata only) |

Fallback while DNS propagates: `https://djmemory-admin.vercel.app` (same project).

## Checklist

### 1. Supabase

1. ~~Create project~~ Done: **DJMemory** (`alywaxyxnaxwbbsiaafs`).
2. ~~Apply [`admin/supabase/migrations/001_initial.sql`](../admin/supabase/migrations/001_initial.sql)~~ Done via MCP.
3. Copy **service_role** key (Settings → API) into `admin/.env.local` as `SUPABASE_SERVICE_ROLE_KEY`.
4. After first Clerk admin signs in, insert:

```sql
insert into public.admin_roles (clerk_user_id, email, role)
values ('user_XXXX', 'you@example.com', 'owner');
```

No Supabase custom domain is required (clients talk to Vercel only).

### 2. Clerk (production + Beat Revival)

Development instance (`*.clerk.accounts.dev` / `pk_test_`) is fine for local. For `beatrevival.com`:

1. Open [dashboard.clerk.com](https://dashboard.clerk.com) → **DJMemory** → switch to **Production**.
2. Copy **Production** Publishable + Secret keys into Vercel + `admin/.env.local` (replace `pk_test_` / `sk_test_`).
3. **Paths / allowed origins:** add `https://beatrevival.com`, `https://www.beatrevival.com`, `https://djmemory-admin.vercel.app`, `http://localhost:3000`.
4. Sign-in URL: `/sign-in`. Redirect URLs: same hosts + native callbacks below.
5. Enable email magic link (and OAuth if desired).
6. **MFA for admins:** MFA is **Clerk Pro** ($25/mo). Enforce MFA for users who hold `admin_roles` once on Pro. Hobby works for waitlist + sign-in without MFA.
7. Optional: Clerk Frontend API custom domain `clerk.beatrevival.com` (Hobby includes custom domain).
8. **Native apps:** Enable **Native API** under [Native applications](https://dashboard.clerk.com/~/native-applications).

| Client | App ID Prefix (Team ID) | Bundle ID | Redirect |
| --- | --- | --- | --- |
| macOS | `3JYK7Q92SF` | `app.setcatcher.SetCatcher` | `app.setcatcher.SetCatcher://callback` |
| iPad companion | `3JYK7Q92SF` | `app.setcatcher.SetCatcher.iPad` | `app.setcatcher.SetCatcher.iPad://callback` |

Associated Domains currently use `webcredentials:glorious-longhorn-36.clerk.accounts.dev` in [`packaging/DJMemory.entitlements`](../packaging/DJMemory.entitlements). After Clerk production + optional custom domain, update Associated Domains to the production Frontend API host. Local protection never depends on Native API being enabled.

### 3. Local env

```sh
cd admin
cp .env.example .env.local
# fill:
# NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=
# CLERK_SECRET_KEY=
# SUPABASE_URL=
# SUPABASE_SERVICE_ROLE_KEY=
# NEXT_PUBLIC_ACCOUNT_URL=https://beatrevival.com
npm run dev
```

### 4. Vercel

**Required:** Project Settings → General → **Root Directory** = `admin` (project `djmemory-admin`). Git integration clones the whole Swift repo; without this, `next build` runs at the repo root and fails with “Couldn't find any `pages` or `app` directory.”

[`admin/vercel.json`](../admin/vercel.json) sets `ignoreCommand` so pushes that do not touch `admin/` skip the web build.

CLI deploy (fallback when you are not relying on Git auto-deploy) still runs from `admin/`:

```sh
cd admin
npx vercel link   # team: acknowledgements-sfc's projects; project djmemory-admin
# confirm: npx vercel project inspect djmemory-admin → Root Directory admin
npx vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY production
npx vercel env add CLERK_SECRET_KEY production
npx vercel env add NEXT_PUBLIC_CLERK_SIGN_IN_URL production   # /sign-in
npx vercel env add SUPABASE_URL production
npx vercel env add SUPABASE_SERVICE_ROLE_KEY production
npx vercel env add NEXT_PUBLIC_ACCOUNT_URL production         # https://beatrevival.com
npx vercel --prod
```

Do not leave Root Directory unset and rely on CLI-only deploys — every `main` push will still trigger a broken Git build.

Domains already attached to `djmemory-admin`: `beatrevival.com`, `www.beatrevival.com`.

### 4a. Hover DNS (human — required for SSL on beatrevival.com)

Registrar: **Hover** (Tucows). Nameservers today: `ns1.hover.com` / `ns2.hover.com`.

In Hover DNS for `beatrevival.com`, set:

| Type | Host | Value |
| --- | --- | --- |
| A | `@` | `76.76.21.21` (or both `216.198.79.1` and `64.29.17.1` if Hover allows multi-A) |
| CNAME or A | `www` | `cname.vercel-dns.com` **or** A `76.76.21.21` |

Remove the existing parking A (`216.40.34.41`).

Then:

```sh
npx vercel domains verify beatrevival.com --scope acknowledgements-sfcs-projects
```

Vercel emails when SSL is ready. Optional: point Hover nameservers to `ns1.vercel-dns.com` / `ns2.vercel-dns.com` instead of individual records.

### 5. macOS / iPad account URL

Default in [`DJMemoryAccountConfiguration`](../Sources/DJMemoryCore/DJMemoryAccountConfiguration.swift) is `https://beatrevival.com`. Override with `DJMEMORY_ACCOUNT_URL` if needed (e.g. still on `https://djmemory-admin.vercel.app` before DNS completes).

Native Clerk sign-in reads `DJMEMORY_CLERK_PUBLISHABLE_KEY` at launch. Leave it unset to keep Account UI inactive in local/offline builds; local protection, archive, scan, import, and diagnostics export still work.

### 6. Smoke

- `GET /api/health` → `{ ok: true, … }`
- `POST /api/waitlist` with `{ "email" }` → pending `beta_invites` row (source Waitlist in `/admin/invites`)
- Sign in → `/admin` (needs `admin_roles` row)
- Create a beta invite → row in `beta_invites` + `admin_audit_events`
- Signed-in Mac: Settings → Refresh Account → device row + license summary
- Signed-in Mac: Upload Diagnostics Metadata → `diagnostic_uploads` row (no titles/artists)
