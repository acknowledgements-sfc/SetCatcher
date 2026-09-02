# DJMemory Admin (accounts + marketing + support)

Optional web accounts, Beat Revival marketing/waitlist, and support-first admin for DJMemory.

Stack: **Clerk** (identity / sessions only) + **Supabase** (licenses, devices, invites, catalog) + **Vercel** (host). Do not enable Clerk Billing or Organizations.

Native Mac/iPad clients send `Authorization: Bearer <session JWT>`. `/api/*` must not use `auth.protect()` (handshake redirects). Email/name for first-time users is loaded via Clerk Backend when `currentUser()` is empty.

Production host: **https://beatrevival.com** (Vercel project `djmemory-admin`).

Local protection in the macOS app **never** depends on this service. Audio and full tracklists are never uploaded by default. Admins cannot play or download audio or view tracklist contents.

## URLs

| Path | Role |
| --- | --- |
| `/` | Marketing + public waitlist |
| `/admin` | Support admin |
| `/sign-in` | Clerk |
| `/api/waitlist` | Public waitlist POST |
| `/api/devices`, `/api/license`, `/api/diagnostics` | Signed-in client API |

## Setup

1. Create a Clerk application. For production on `beatrevival.com`, use the **Production** instance and allowlist that host (see [`docs/accounts-deploy.md`](../docs/accounts-deploy.md)). Enforce MFA for admin users once on Clerk Pro.
2. Create a Supabase project. Run [`supabase/migrations/001_initial.sql`](supabase/migrations/001_initial.sql).
3. Insert your admin row:

```sql
insert into public.admin_roles (clerk_user_id, email, role)
values ('user_xxx', 'you@example.com', 'owner');
```

4. Copy `.env.example` to `.env.local` and fill keys (`NEXT_PUBLIC_ACCOUNT_URL=https://beatrevival.com` in production).
5. `npm install && npm run dev`
6. Deploy `admin/` to Vercel; set the same env vars. Attach `beatrevival.com` and configure Hover DNS (A `@` → `76.76.21.21`).

## Scripts

- `npm run dev` — local Next.js
- `npm run build` — production build
- `npm run start` — serve production build

## Privacy

- Diagnostics uploads accept **metadata only** (counts, paths, timings, errors).
- Server routes use the Supabase **service role**; anon/authenticated have no table grants.
- Every admin search, detail view, and mutation writes `admin_audit_events`.
- Waitlist stores email only in `beta_invites` (no audio, no tracklists).
