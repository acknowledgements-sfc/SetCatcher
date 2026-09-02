import assert from "node:assert/strict";
import { profileFromClerkUser } from "./clerk-profile.ts";

const primary = profileFromClerkUser({
  primaryEmailAddress: { emailAddress: "dj@example.com" },
  emailAddresses: [{ emailAddress: "other@example.com" }],
  fullName: "DJ Example",
});
assert.equal(primary.email, "dj@example.com");
assert.equal(primary.displayName, "DJ Example");

const fallbackEmail = profileFromClerkUser({
  emailAddresses: [{ emailAddress: "only@example.com" }],
  firstName: "Only",
});
assert.equal(fallbackEmail.email, "only@example.com");
assert.equal(fallbackEmail.displayName, "Only");

const empty = profileFromClerkUser({});
assert.equal(empty.email, null);
assert.equal(empty.displayName, null);

console.log("clerk-profile: ok");
