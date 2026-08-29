# Manual macOS accessibility notes (Phase 4)

Automated proof does not cover VoiceOver or keyboard focus. Record manual checks against the debug app.

Date: 2026-08-29  
App: `.build/DJMemory.app` (debug)

## Checklist

| Check | Status | Notes |
|-------|--------|-------|
| Keyboard navigation (sidebar → content) | Pending operator | |
| Visible focus rings on search / pickers | Pending operator | `library.archivedSets.search`, `library.segment`, `library.dateFilter` |
| VoiceOver names and roles | Pending operator | |
| Labeled search fields and pickers | Pending operator | |
| Recovery and error actions named + actionable | Pending operator | |
| Disabled scanning controls announced | Pending operator | |

Static automated coverage: `AccessibilityIdentifierAuditTests` asserts required identifier **families** remain present in `Sources/DJMemoryApp`. Existing identifiers must not be renamed or removed.
