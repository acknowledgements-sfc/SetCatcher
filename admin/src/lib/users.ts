import { loadClerkProfile } from "./clerk-user";
import { writeAuditEvent } from "./audit";
import { getServiceSupabase, type DbUser } from "./supabase";

/** Ensure a `users` row exists for the signed-in Clerk user. Creates a free license on first sight. */
export async function ensureAppUser(clerkUserId: string): Promise<DbUser> {
  const supabase = getServiceSupabase();
  const { data: existing, error: lookupError } = await supabase
    .from("users")
    .select("*")
    .eq("clerk_user_id", clerkUserId)
    .maybeSingle();

  if (lookupError) {
    throw new Error(`User lookup failed: ${lookupError.message}`);
  }
  if (existing) {
    return existing as DbUser;
  }

  const profile = await loadClerkProfile(clerkUserId);
  const email = profile.email || `${clerkUserId}@users.clerk.local`;
  const displayName = profile.displayName;

  const { data: created, error: insertError } = await supabase
    .from("users")
    .insert({
      clerk_user_id: clerkUserId,
      email,
      display_name: displayName,
      status: "active",
      release_channel: "stable",
    })
    .select("*")
    .single();

  if (insertError) {
    // Race: another request inserted first.
    const { data: raced, error: raceError } = await supabase
      .from("users")
      .select("*")
      .eq("clerk_user_id", clerkUserId)
      .maybeSingle();
    if (raceError || !raced) {
      throw new Error(`User create failed: ${insertError.message}`);
    }
    return raced as DbUser;
  }

  const user = created as DbUser;
  const { error: licenseError } = await supabase.from("licenses").insert({
    user_id: user.id,
    plan: "free",
    status: "active",
  });
  if (licenseError) {
    // Non-fatal for subsequent GET /api/license which will still default offline-full.
    console.error("license seed failed", licenseError.message);
  }

  await acceptPendingInvitesForEmail({
    email: user.email,
    clerkUserId,
  });

  return user;
}

/** Mark pending waitlist/admin invites for this email as accepted (first sign-in only). */
async function acceptPendingInvitesForEmail(input: {
  email: string;
  clerkUserId: string;
}) {
  const normalized = input.email.trim().toLowerCase();
  if (!normalized || normalized.endsWith("@users.clerk.local")) {
    return;
  }

  const supabase = getServiceSupabase();
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("beta_invites")
    .update({ status: "accepted", accepted_at: now })
    .eq("email", normalized)
    .eq("status", "pending")
    .select("id");

  if (error) {
    console.error("invite accept failed", error.message);
    return;
  }

  const accepted = data ?? [];
  if (accepted.length === 0) {
    return;
  }

  await writeAuditEvent({
    actorClerkId: input.clerkUserId,
    actorEmail: normalized,
    action: "invites.accept",
    target: normalized,
    result: `accepted:${accepted.length}`,
  });
}

const FORBIDDEN_DIAGNOSTIC_KEYS = new Set([
  "title",
  "artist",
  "tracks",
  "tracklist",
  "titles",
  "artists",
  "trackTitles",
  "track_titles",
]);

/** Strip forbidden keys recursively so metadata stays counts/paths/errors only. */
export function sanitizeDiagnosticMetadata(
  input: unknown
): Record<string, unknown> {
  if (input === null || typeof input !== "object" || Array.isArray(input)) {
    return {};
  }

  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input as Record<string, unknown>)) {
    if (FORBIDDEN_DIAGNOSTIC_KEYS.has(key)) {
      continue;
    }
    if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      out[key] = sanitizeDiagnosticMetadata(value);
    } else if (Array.isArray(value)) {
      out[key] = value.map((item) =>
        item !== null && typeof item === "object" && !Array.isArray(item)
          ? sanitizeDiagnosticMetadata(item)
          : item
      );
    } else {
      out[key] = value;
    }
  }
  return out;
}
