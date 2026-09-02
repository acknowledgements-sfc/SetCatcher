import { auth } from "@clerk/nextjs/server";
import { loadClerkProfile } from "./clerk-user";
import { getServiceSupabase, type AdminRole } from "./supabase";

const MUTATING_ROLES: AdminRole[] = ["owner", "support", "release_manager"];

/**
 * Cookie sessions (web admin) and native Bearer session JWTs (Mac / iPad).
 * Do not call `auth.protect()` on `/api/*` — handshake redirects break native clients.
 */
export async function requireSignedIn() {
  const session = await auth({ acceptsToken: "session_token" });
  if (!session.userId) {
    throw new Error("Unauthorized");
  }
  return session;
}

export async function requireAdmin(): Promise<{
  clerkUserId: string;
  email: string | null;
  role: AdminRole;
}> {
  const session = await requireSignedIn();

  const supabase = getServiceSupabase();
  const { data, error } = await supabase
    .from("admin_roles")
    .select("role, email")
    .eq("clerk_user_id", session.userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Admin role lookup failed: ${error.message}`);
  }
  if (!data?.role) {
    throw new Error("Forbidden");
  }

  const profile = await loadClerkProfile(session.userId);
  const email = data.email || profile.email || null;

  return {
    clerkUserId: session.userId,
    email,
    role: data.role as AdminRole,
  };
}

export function canMutate(role: AdminRole): boolean {
  return MUTATING_ROLES.includes(role);
}

export function canManageInvites(role: AdminRole): boolean {
  return role === "owner" || role === "release_manager" || role === "support";
}
