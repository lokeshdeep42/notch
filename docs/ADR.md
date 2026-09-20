# Architecture Decision Record

Append-only. One entry per non-obvious decision. Keep them short.

Template:

```
## YYYY-MM-DD — <decision in one line>
**Context:** what forced a choice
**Decision:** what we did
**Alternatives:** what we rejected and why
**Consequences:** what this makes easy or hard later
```

---

## Decisions that must be recorded during the build

These are the open questions flagged in the specs. Each needs an entry once resolved:

- [ ] Panel window level: `.statusBar` (25) vs `NSMainMenuWindowLevel + 3` (27) — which stacks
      correctly against the menu bar, Spotlight, and notification banners, on which OS versions
- [ ] Hover detection: `NSTrackingArea` vs global mouse-moved monitor — which proved reliable over
      the notch cutout
- [x] `ungive/mediaremote-adapter`: its licence, and whether bundling it is permitted — BSD-3, see 2026-09-19
- [ ] macOS 15.4+ pasteboard privacy alert: does poll-then-read trigger it, and what the clipboard
      design became as a result
- [ ] Hardened runtime and the Perl subprocess: which entitlements, if any, were needed
- [ ] MediaRemote command/write support on macOS 26.x: available or hide the transport controls
- [x] Clipboard store: plain JSON vs GRDB — JSON, see 2026-09-19
- [x] Whether `DynamicNotchKit` stayed as a dependency or was replaced with owned code — never added
- [ ] Final product name and the trademark check behind it

---

## Entries

## 2026-09-19 — SwiftPM package + build script instead of XcodeGen
**Context:** Code is written on Windows and verified on a borrowed Mac; there is no Xcode here.
**Decision:** `Package.swift` with one target per module; `Scripts/build.sh` assembles `Sill.app`
(Info.plist, bundled adapter, ad-hoc signature). CI on GitHub Actions `macos-15` builds, tests and
uploads the app on every push; logs are published to the `ci-logs` branch.
**Alternatives:** XcodeGen `project.yml` (needs Xcode + XcodeGen on the Mac, and can't be checked
from Windows); a checked-in `.xcodeproj` (unreviewable diffs).
**Consequences:** The compiler enforces "features never import each other". Release signing
(hardened runtime, Developer ID) still needs a real `sign.sh` in M9.

## 2026-09-19 — AppKit entry point; settings in our own window
**Context:** SwiftUI's `Settings` scene is unreliable to open from an `LSUIElement` agent app on 14+.
**Decision:** `@main enum SillMain` + `AppDelegate`; settings and onboarding are `NSWindow`s hosting
SwiftUI, torn down on close.
**Alternatives:** SwiftUI `App` + `Settings` scene with `SettingsLink`.
**Consequences:** Full control of activation; one extra controller class per window.

## 2026-09-19 — Swift 5 language mode for the first builds
**Context:** CLAUDE.md asks for Swift 6 "where practical". Writing strict-concurrency code without a
compiler would have produced a long tail of blind fixes.
**Decision:** tools-version 5.9, Swift 5 mode, `@MainActor` on every UI type, `MainActor.assumeIsolated`
in AppKit callbacks delivered on the main queue. CI reports 0 warnings.
**Alternatives:** Swift 6 mode from the start.
**Consequences:** Switch to Swift 6 mode once the app is verified on hardware; expect a small batch
of `Sendable` fixes (callbacks, `Process` termination handlers).

## 2026-09-19 — Owned notch window code; DynamicNotchKit not used
**Context:** M0-T2 suggested adding DynamicNotchKit (MIT) to prove feasibility quickly.
**Decision:** Skipped. The panel, shape, hit-testing and per-display management are owned code from
the first commit, because "the window behaviour *is* the product" (01-ARCHITECTURE).
**Consequences:** One fewer dependency; M0 feasibility is proven by our own code or not at all.

## 2026-09-19 — mediaremote-adapter v0.7.7 bundled (BSD-3-Clause)
**Context:** Open question: the adapter's licence.
**Decision:** Licence confirmed BSD-3-Clause ("Copyright (c) 2025, Jonas van den Berg and
contributors"). Pinned to tag v0.7.7, built by `Scripts/fetch-adapter.sh`, framework in
`Contents/Frameworks`, script and LICENSE in `Contents/Resources`, credited in About.
Invoked as `perl … stream --micros --debounce=100`. The stream runs while Now Playing is enabled —
not only while the panel is open — because track-change peeks and collapsed wings need it.
**Consequences:** Its idle cost must be measured separately (`bench.sh` now samples the helper).
If it's not ~0, fall back to running it only while the panel is visible and drop peeks.

## 2026-09-19 — Music/Spotify fallback via distributed notifications, not polling
**Context:** 02-TECHNICAL-REFERENCE said the scripting fallback "requires polling".
**Decision:** `com.apple.Music.playerInfo` and `com.spotify.client.PlaybackStateChanged` distributed
notifications give title/artist/album/state with no permission and no polling. Apple Events are used
only for play/pause/skip, after an in-panel explanation of the one-time Automation prompt.
**Consequences:** No artwork and no live position in fallback mode; seeking is adapter-only.

## 2026-09-19 — Shelf drag-out writes file URLs with a copy-only mask
**Context:** The spec called for `NSFilePromiseProvider`.
**Decision:** Items already live as real files in our store, so the drag source writes `NSURL`s and
returns `.copy` from `sourceOperationMaskFor`. Finder copies (never moves) and browser upload
fields, Mail and Slack accept URLs, which they often don't for promises. Incoming promises (Photos,
Mail) *are* received via `NSFilePromiseReceiver`.
**Consequences:** Simpler code; verify on hardware that no target moves the file out of the store.

## 2026-09-19 — Intent-aware hover
**Context:** "Expands when you're reaching for the menu bar" is the category-wide complaint.
**Decision:** Besides the enter delay and dead zone, `HoverIntent` estimates pointer velocity from
the tracking area's `mouseMoved` events (only delivered inside the zone, so zero idle cost). A
settled pointer opens early; a fast upward throw restarts the delay. User can turn it off.
**Consequences:** Thresholds (140 pt/s settle, 900 pt/s throw) need tuning by feel on hardware.

## 2026-09-19 — Magnetic drop zone via global mouse monitors
**Context:** The shelf should open *before* a dragged file reaches the notch.
**Decision:** `DragMagnet` installs global monitors for left mouse down/dragged/up. Mouse monitors
need no permission (only keyboard monitors do) and receive nothing while the mouse is idle or just
moving. File-ness is decided once per drag from the drag pasteboard's `changeCount`. Fallback: the
panel's own drag destination opens it when the pointer arrives.
**Measured cost:** not yet — see docs/VERIFY-ON-MAC.md §3/§5.

## 2026-09-19 — Clamshell fallback for "built-in display only"
**Decision:** If no built-in display is active, the panel goes to the menu-bar display instead of
disappearing. Same for "chosen displays" when none of the chosen ones is connected.

## 2026-09-19 — Collapsed battery indicator off by default
**Context:** Spec v1 item 6 puts battery status in the collapsed pill.
**Decision:** Opt-in (Settings → Modules). The charger peek always shows. "The notch app that
disappears" means nothing beside the notch unless something is happening.

## 2026-09-19 — Clipboard: tab always visible, capture off by default, copy-not-paste
**Decision:** The tab exists so the feature is discoverable; the pasteboard is never read until the
user turns capture on. Enter copies the entry back and closes the panel; the user presses ⌘V.
Synthesising the paste would need Accessibility, which v1 does not request.
**Open:** the macOS 15.4+ pasteboard privacy alert is still unverified (VERIFY-ON-MAC §5).

## 2026-09-19 — Plain JSON stores for shelf and clipboard
**Decision:** JSON manifests plus blob files, capped by count and bytes and pruned on launch. GRDB
not added. Revisit only if clipboard search becomes slow at the cap.

## 2026-09-20 — Display eligibility extracted as a pure rule
**Context:** "Multi-display correctness is a v1 feature" (CLAUDE.md §6), but the rules lived inside
`NotchWindowManager.desiredDisplays()` behind `NSScreen.screens`, so no row of the QA display
matrix could be tested anywhere but on a Mac with monitors plugged in.
**Decision:** `DisplayEligibility.eligible(among:mode:chosenUUIDs:)` over a `DisplayCandidate`
value type. `desiredDisplays()` builds candidates from `NSScreen` and calls it. Behaviour is
unchanged, including both fallbacks (clamshell, all-chosen-unplugged) and the `NSScreen.screens`
ordering that makes the first entry the menu-bar display.
**Alternatives:** injecting a screen provider protocol into the manager — more machinery, and the
manager's remaining work is all AppKit side effects that a fake screen would not exercise anyway.
**Consequences:** the mode rules, both fallbacks and idempotence under rapid plug/unplug are now
unit-tested on any machine. UUID lookup is still only performed in `.chosen` mode, so reconcile
costs no more CoreGraphics round-trips than before.

## 2026-09-20 — CI launches the app (smoke test), as a probe rather than a gate
**Context:** CI compiled the app and ran unit tests but had never once launched it, so a crash on
launch, a malformed Info.plist or a missing bundled resource would have shipped green.
**Decision:** `Scripts/smoke.sh` runs the binary inside the bundle, holds it for 12 s, records RSS,
takes a screenshot, dumps the unified log, then SIGTERMs it and fails if the process ignores the
signal or leaves a `mediaremote-adapter.pl` helper behind (QA checklist §Performance). CI runs it
with `continue-on-error` and publishes `smoke=` in the ci-logs status, because whether a GitHub
runner offers a usable window server is itself unverified.
**Alternatives:** XCUITest — needs an Xcode project and driving a menu-bar app with no windows;
`open` instead of the binary — loses stdout, where AppKit faults surface first.
**Consequences:** launch regressions and helper leaks are caught per-push, and each run leaves a
screenshot of the panel in its no-notch fallback form. It proves nothing about notch geometry,
hover or energy: runners have no notch and a VM's power numbers are meaningless. Promote to the
hard fail gate once it has passed a few runs.

## 2026-09-20 — Quit cleanly on SIGTERM/SIGINT
**Context:** the CI smoke test's first run found it: Sill dies on SIGTERM without running
`applicationWillTerminate`, so `AdapterProcess.stop()` never fires and the `/usr/bin/perl` Now
Playing helper is orphaned. SIGTERM is what logout, restart and `killall` send, so this is not a
test-only path — a stray perl process in a battery report is the exact failure this product sells
against.
**Decision:** `AppDelegate` disarms the default disposition for SIGTERM and SIGINT and takes them
on a `DispatchSource` signal source on the main queue, which calls `NSApp.terminate(nil)`. The
normal teardown then runs as it does for menu-bar Quit.
**Alternatives:** an `atexit` handler (does not run on signal death either); having the helper exit
on parent death via an stdin pipe — better in that it also survives SIGKILL, but it needs a change
to the vendored adapter, so it stays a follow-up.
**Consequences:** SIGKILL and a hard crash still orphan the helper. Worth revisiting if it shows up
on hardware. A signal source is event-driven: no timer, no poll, no idle cost.

## Still open (need the Mac)
- Panel window level (`.statusBar` used) vs. Spotlight / notification banners.
- Tracking-area reliability over the notch cutout.
- Whether global `leftMouseDragged` monitors fire during Finder drag sessions.
- Hardened runtime + `/usr/bin/perl` subprocess entitlements (M9).
- MediaRemote command support on macOS 26.x.
- macOS 15.4+ pasteboard alert behaviour.
- Final product name (candidates: **Lintel**, Hush, Eave) and its trademark check.
