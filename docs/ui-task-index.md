# UI task index

Tracking goal: [#1](https://github.com/acknowledgements-sfc/SetCatcher/issues/1) (**closed** — shipped)
Spec: [`HANDOFF.md`](../HANDOFF.md) · Rules: [`AGENTS.md`](../AGENTS.md)

T1–T13 are **done on main**. Issues #1–#14 were closed 2026-08-09 as stale trackers.

Next build tracks: accounts client APIs (done), accounts deploy ops, Mac beta Round 2, iPad companion ([`docs/ipad-companion.md`](ipad-companion.md)).

| | Task | Issue |
| --- | --- | --- |
| T1 | Design token layer (`Theme/Tokens.swift`) | [#2](https://github.com/acknowledgements-sfc/SetCatcher/issues/2) closed |
| T2 | Split `ContentView.swift`, add `Route` enum | [#3](https://github.com/acknowledgements-sfc/SetCatcher/issues/3) closed |
| T3 | Shared UI primitives | [#4](https://github.com/acknowledgements-sfc/SetCatcher/issues/4) closed |
| T4 | `SetCatcherCore` gaps G1–G5 | [#5](https://github.com/acknowledgements-sfc/SetCatcher/issues/5) closed |
| T5 | Protection dashboard | [#6](https://github.com/acknowledgements-sfc/SetCatcher/issues/6) closed |
| T6 | Per-app setup | [#7](https://github.com/acknowledgements-sfc/SetCatcher/issues/7) closed |
| T7 | Library | [#8](https://github.com/acknowledgements-sfc/SetCatcher/issues/8) closed |
| T8 | Activity + Settings | [#9](https://github.com/acknowledgements-sfc/SetCatcher/issues/9) closed |
| T9 | Onboarding flow | [#10](https://github.com/acknowledgements-sfc/SetCatcher/issues/10) closed |
| T10 | Folder recovery flow | [#11](https://github.com/acknowledgements-sfc/SetCatcher/issues/11) closed |
| T11 | Previews and interaction polish | [#12](https://github.com/acknowledgements-sfc/SetCatcher/issues/12) closed |
| T12 | Home dashboard | [#13](https://github.com/acknowledgements-sfc/SetCatcher/issues/13) closed |
| T13 | Sidebar sources + add-app picker | [#14](https://github.com/acknowledgements-sfc/SetCatcher/issues/14) closed |

`swift build`, `swift test`, and `bash scripts/smoke-app.sh` must pass for Mac UI work, and every
existing `.accessibilityIdentifier` must survive.
