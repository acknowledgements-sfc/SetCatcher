/**
 * Show landing: full-viewport shell over the static generated-light page.
 * Waitlist UI is visual-only for now (no /api/waitlist POST).
 * Admin + API routes are unchanged under /admin and /api.
 */
export default function HomePage() {
  return (
    <iframe
      src="/generated-light.html"
      title="SetCatcher"
      style={{
        position: "fixed",
        inset: 0,
        width: "100vw",
        height: "100vh",
        border: "none",
        display: "block",
        background: "#0A0A0A",
      }}
    />
  );
}
