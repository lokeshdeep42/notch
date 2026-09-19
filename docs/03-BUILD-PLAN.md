# 03 — Build Plan

Work milestones in order. Each task has acceptance criteria; do not advance until they pass.
Task IDs are stable — reference them in commit messages (`feat(notch): M2-T3 hover debounce`).

---

## Milestone 0 — De-risk (do this first, before anything else)

**Purpose:** find out within a few hours whether the hard part is achievable. The riskiest unknown
in this entire project is: *a borderless panel positioned over the notch that stays correct across
Spaces, fullscreen, sleep/wake and display changes, while costing essentially nothing when idle.*
If that is not achievable, the product does not exist and we should know immediately.

| ID | Task | Acceptance criteria |
|---|---|---|
| M0-T1 | New Xcode project, `LSUIElement`, empty agent app, menu bar item with Quit | App launches, no Dock icon, quits cleanly |
| M0-T2 | Add `DynamicNotchKit` (MIT) via SPM and render *anything* at the notch | Something visible at the notch within 30 minutes — this is a feasibility check, not the final code |
| M0-T3 | Hand-rolled `NotchPanel` per `02-TECHNICAL-REFERENCE` §3 | A coloured rectangle sits flush over the notch on the built-in display |
| M0-T4 | Notch geometry detection | Correct width/height on the actual machine; correct fallback pill on a non-notched external display |
| M0-T5 | Display reconfiguration handling | Unplug/replug an external display 5× — panel is correct every time, no duplicates, no orphans |
| M0-T6 | Sleep/wake handling | Close the lid, reopen, panel is correct. Repeat with external display attached. |
| M0-T7 | Space / fullscreen behaviour | Panel visible on every Space; correctly suppressed under a fullscreen app |
| M0-T8 | `Scripts/bench.sh` + 2-hour idle soak | **≤ 0.1% average CPU**, near-zero idle wakeups, < 80 MB RSS |

**Gate:** if M0-T8 fails, stop and fix before writing a single feature. This is the wedge.

---

## Milestone 1 — App skeleton

| ID | Task | Acceptance criteria |
|---|---|---|
| M1-T1 | Restructure into the Swift Package layout from `01-ARCHITECTURE` | Modules build independently; `Tests/` runs |
| M1-T2 | `Preferences` service with typed keys | Values persist across launches |
| M1-T3 | `LaunchAtLogin` via `SMAppService` | Toggle works; `.requiresApproval` surfaces a real message, not a silent failure |
| M1-T4 | `Log` (os.Logger categories) + debug overlay behind a defaults flag | Overlay shows state, display ID, FPS, wakeups |
| M1-T5 | `Branding` constant; app name referenced from exactly one place | Renaming the app is a one-line change |
| M1-T6 | `Scripts/build.sh`, `test.sh`, `bench.sh` | All three run from a clean checkout |

---

## Milestone 2 — Notch engine (the core)

| ID | Task | Acceptance criteria |
|---|---|---|
| M2-T1 | `NotchState` state machine with unit tests | Every transition in `01-ARCHITECTURE` covered by a test |
| M2-T2 | `NotchWindowManager`, one controller per display, idempotent reconciliation | Rapid plug/unplug cycles leave exactly the right set of panels |
| M2-T3 | `HoverMonitor`: tracking area, enter/exit delays, dead zone | Throwing the pointer at the menu bar 20× never opens the panel; deliberate hover opens it every time |
| M2-T4 | `PassthroughView` hit-testing | Clicking anywhere outside the visible shape reaches the app underneath — verify with a browser tab strip |
| M2-T5 | `NotchShape` with animated radii | Shape reads as continuous with the hardware cutout at both sizes |
| M2-T6 | Expand/collapse animation with `Motion` constants | No frame drops in Instruments; no window-frame animation; reduce-motion respected |
| M2-T7 | Simulated pill for non-notched screens, with size preference | Looks deliberate on a 27" external display, not like a bug |
| M2-T8 | Per-display preference (built-in only / all / chosen) | Setting is respected immediately without relaunch |
| M2-T9 | `suppressed` state: fullscreen, locked session, user pause | Panel fully torn down — verify observers are removed, not just hidden |
| M2-T10 | Re-run `bench.sh` | Budget still met with the full engine in place |

**Gate:** M2 is the product. Spend time here. If the hover feel is not excellent, iterate before
moving on — no feature will compensate for it.

---

## Milestone 3 — Now Playing

| ID | Task | Acceptance criteria |
|---|---|---|
| M3-T1 | Vendor `mediaremote-adapter`, confirm and record its licence | Licence recorded in `docs/ADR.md`; helper runs from the app bundle |
| M3-T2 | Supervised helper process + NDJSON stream decoder | Killing the helper manually → it restarts with backoff; killing it repeatedly → graceful fallback |
| M3-T3 | Collapsed peek: track change shows a brief pill animation, then collapses | Peek never interrupts an open panel |
| M3-T4 | Expanded view: artwork, title, artist, scrubber, transport | Artwork downsampled and cached; no main-thread image work |
| M3-T5 | ScriptingBridge fallback for Music and Spotify | Only attempted after adapter failure; only for running apps; prompts explained before the system dialog |
| M3-T6 | Honest empty state | "No media detected" with a help link — never a spinner |
| M3-T7 | Terminate the helper on suppress/quit/feature-off | `pgrep` finds nothing after quit |
| M3-T8 | Test on macOS 15.4+ and 26.x | Documented result for each; `02-TECHNICAL-REFERENCE` updated |

---

## Milestone 4 — File shelf

| ID | Task | Acceptance criteria |
|---|---|---|
| M4-T1 | Drag-enter auto-expands the collapsed panel into drop mode | Works from Finder, Safari, Mail, Photos |
| M4-T2 | Drop handling: copy into app storage, JSON manifest | Deleting the original leaves the shelf item intact |
| M4-T3 | Thumbnails via `QLThumbnailGenerator`, cached, off main actor | Dropping 50 files does not block the UI |
| M4-T4 | Drag out via `NSFilePromiseProvider` | Dragging to Finder, Mail compose, and Slack all produce real files |
| M4-T5 | Pin / multi-select / context menu (Reveal, Share, Remove) | Pinned items survive "Clear all" |
| M4-T6 | Caps and pruning by count and bytes | Store never exceeds the configured cap |

---

## Milestone 5 — Clipboard history

| ID | Task | Acceptance criteria |
|---|---|---|
| M5-T1 | **Probe the macOS 15.4 pasteboard alert first** with a signed bundle | Documented, definitive answer written into `02-TECHNICAL-REFERENCE` before any further work |
| M5-T2 | `changeCount` poller with full gating (off by default, suspend on sleep/lock/idle) | Measured cost documented and shown in settings next to the toggle |
| M5-T3 | Store: text, image, file entries with caps | Survives relaunch; prunes on launch |
| M5-T4 | Concealed-type and app-blocklist filtering | Copying from a password manager produces no entry |
| M5-T5 | Search UI in the expanded panel | Keyboard-first: type to filter, arrows to select, Enter to paste |
| M5-T6 | Clear history / pause capture controls | Both obvious and immediate |

---

## Milestone 6 — Power status

| ID | Task | Acceptance criteria |
|---|---|---|
| M6-T1 | `IOPSNotificationCreateRunLoopSource` callback, no polling | Battery changes reflected without any timer |
| M6-T2 | Collapsed indicator + plug-in peek animation | Peek fires on connect/disconnect only |
| M6-T3 | Battery health / cycle count in expanded view | Values match System Information |

---

## Milestone 7 — Settings and onboarding

| ID | Task | Acceptance criteria |
|---|---|---|
| M7-T1 | Settings window: General, Appearance, Modules, Advanced, About | Never more than one level of nesting — "settings maze" is a named competitor complaint |
| M7-T2 | Hover tuning UI with live preview | Changing the delay is felt immediately, no relaunch |
| M7-T3 | Permission onboarding flow with live status re-checks | Re-check on wake and activate; never a stale "not granted" |
| M7-T4 | First-run experience: 3 screens maximum, skippable | A new user reaches a working panel in under 30 seconds |
| M7-T5 | Module toggles that fully unload their feature | Disabling clipboard stops the timer and removes observers — verify with `bench.sh` |

---

## Milestone 8 — Licensing and trial

| ID | Task | Acceptance criteria |
|---|---|---|
| M8-T1 | Pick and integrate a merchant-of-record (Polar / Lemon Squeezy / Paddle) | Never raw Stripe alone — see `05-RELEASE.md` |
| M8-T2 | Licence key activation, offline grace period, device limit | Works offline for N days after a successful check |
| M8-T3 | 14-day trial with honest countdown | No nagging before day 10; clear, non-hostile expiry |
| M8-T4 | Free-tier gating (media + battery free; shelf/clipboard/tuning paid) | Gate is clear, never a surprise mid-action |

---

## Milestone 9 — Packaging and release engineering

| ID | Task | Acceptance criteria |
|---|---|---|
| M9-T1 | Developer ID signing, hardened runtime, entitlements | Bundled helper and framework correctly signed |
| M9-T2 | Notarisation + stapling script | `spctl -a -vvv` passes on a clean machine |
| M9-T3 | Sparkle 2 with EdDSA-signed appcast | A test update installs end-to-end |
| M9-T4 | DMG with background and Applications symlink | Opens correctly on a clean machine |
| M9-T5 | Crash handling that does **not** phone home by default | Opt-in only; privacy is part of the pitch |

---

## Milestone 10 — QA and beta

Run the full matrix in `docs/04-QA-CHECKLIST.md`. Recruit 5–10 testers, weighted toward people who
uninstalled a competitor. Ask them three specific questions: did it ever open when you didn't want
it to, did anything break when you plugged in a monitor, did you notice it in your battery usage.

---

## Weekend sprint mapping

You will not finish v1 this weekend, and trying to will produce a bad core. Here is what a
realistic, genuinely productive weekend looks like:

### Saturday
| Block | Work | Output |
|---|---|---|
| Morning (3h) | **M0 entirely** | You know whether this is buildable. This is the highest-value block of the whole project. |
| Afternoon (3h) | M1-T1 … M1-T6, then M2-T1, M2-T2 | Clean project structure, state machine with tests, per-display manager |
| Evening (2h) | M2-T3, M2-T4 | Hover feels right; clicks pass through correctly |
| Overnight | Leave `bench.sh` soaking | Idle numbers waiting for you in the morning |

### Sunday
| Block | Work | Output |
|---|---|---|
| Morning (3h) | M2-T5 … M2-T10 | The notch engine is done and feels good |
| Afternoon (3h) | M3-T1 … M3-T4 | Now Playing renders — the first moment it looks like a real product |
| Evening (2h) | M3-T6, M3-T7, re-run bench, write up findings | Working prototype; docs updated with what turned out to be wrong |

**Deliberately skip this weekend:** shelf, clipboard, settings UI, licensing, packaging, any
feature from the v2 list. Resist all of them.

**Screenshot and record the prototype on Sunday night.** A short clip of a smooth expand animation
is the single most useful marketing asset you can produce, and it costs ten minutes.
