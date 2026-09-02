import { clerkClient, currentUser } from "@clerk/nextjs/server";
import { profileFromClerkUser, type ClerkProfile } from "./clerk-profile";

export type { ClerkProfile };

/**
 * Prefer `currentUser()` (cookie + some session JWTs). Fall back to the Backend API
 * when a native `Authorization: Bearer` token has `userId` but no hydrated user object.
 */
export async function loadClerkProfile(clerkUserId: string): Promise<ClerkProfile> {
  const sessionUser = await currentUser();
  if (sessionUser?.id === clerkUserId) {
    return profileFromClerkUser(sessionUser);
  }
  try {
    const client = await clerkClient();
    const user = await client.users.getUser(clerkUserId);
    return profileFromClerkUser(user);
  } catch {
    return { email: null, displayName: null };
  }
}
