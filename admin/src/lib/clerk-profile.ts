export type ClerkProfile = {
  email: string | null;
  displayName: string | null;
};

export type ClerkEmailSource = {
  id?: string;
  primaryEmailAddress?: { emailAddress: string } | null;
  emailAddresses?: Array<{ emailAddress: string }>;
  fullName?: string | null;
  username?: string | null;
  firstName?: string | null;
};

/** Pure mapping so native Bearer sessions and cookie sessions share one email/name path. */
export function profileFromClerkUser(user: ClerkEmailSource): ClerkProfile {
  const email =
    user.primaryEmailAddress?.emailAddress ||
    user.emailAddresses?.[0]?.emailAddress ||
    null;
  const displayName = user.fullName || user.username || user.firstName || null;
  return { email, displayName };
}
