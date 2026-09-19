# Sill v1 — Design (approved 2026-09-19)

Builds on `docs/00`–`05`. This file records only what the brainstorm **added to** or **changed in**
those docs. Where they disagree, this file wins and the originals are updated in the same commit.

## Scope

All v1 features from `00-PRODUCT-SPEC.md` **except** licensing, trial, Sparkle, notarisation and DMG
(M8, M9 — they need paid accounts). Name stays **Sill** (placeholder, `Branding.swift`).

Development constraint: code is authored on Windows and verified on a borrowed MacBook. Everything
that needs hardware goes into `docs/VERIFY-ON-MAC.md` as one checklist.

## Differentiators ("the one that stands out")

1. **Intent-aware hover.** `HoverIntent` (pure, tested) reads pointer velocity from tracking-area
   `mouseMoved` events. Slow + inside → open early. Fast + moving upward → restart the enter delay
   (a throw at the menu bar passes through). Still pointer → normal enter delay fallback. No timers
   beyond one-shot cancellable `Task.sleep`.
2. **Live cost receipt.** Footer of the open panel: CPU % averaged since launch, wakeups/hour,
   memory footprint — read from `task_info(TASK_POWER_INFO_V2, TASK_VM_INFO)` once per open.
   No timer.
3. **Magnetic drop zone.** A global `leftMouseDragged` monitor (no permission, zero cost when no
   drag is happening) detects a file drag approaching the notch. The collapsed shape leans toward
   the cursor with strength by distance, then opens straight into the shelf.
4. **Physical motion.** Shape grows down and out from the hardware notch; springs retarget from
   the on-screen value (interruptible); content materialises (opacity + blur + scale from top)
   50 ms behind the shape; Reduce Motion → cross-fade. Collapsed state never animates per frame.

## Changes to the spec pack

| Doc said | Now | Why |
|---|---|---|
| XcodeGen `project.yml` | SwiftPM `Package.swift` + `Scripts/build.sh` assembles `Sill.app` | One command on the Mac; module boundaries enforced by the compiler |
| `@main SillApp` (SwiftUI App) | AppKit `main.swift` + `AppDelegate`; settings in our own `NSWindow` | Opening a SwiftUI `Settings` scene from an agent app is unreliable on 14+ |
| Swift 6 mode | Swift 5 mode, `@MainActor` on UI types | Blind compilation; switch after first green build |
| `NSFilePromiseProvider` drag-out | Drag stored file URL, `.copy`-only operation mask | Files already live in our store; browsers accept URLs, not promises |
| Scripting fallback "requires polling" | Music/Spotify **distributed notifications** for state (no poll, no permission); Apple Events only for controls, on first use | Event-driven, fewer prompts |
| Battery in collapsed pill | Preference, **default off**; always peek on plug/unplug | "The app that disappears" |
| Enter to paste | Enter copies + closes; user presses ⌘V | Synthesising ⌘V needs Accessibility |
| `NotchRootView` routes to features | `NotchModule` protocol in `NotchCore`; app target registers modules | Core must not import features |

## Module map

`DesignSystem` ← `Services` ← `NotchCore` ← `Feature*` ← `SettingsUI` ← `SillApp` (executable).
Features never import each other.

## Now Playing

`ungive/mediaremote-adapter` — **BSD-3-Clause** (confirmed 2026-09-19). Invoked as
`/usr/bin/perl <script> <framework> stream --debounce=100`. NDJSON lines
`{"type":"data","diff":bool,"payload":{...}}`; diff payloads merge into the last full payload,
`null` removes a key; an empty payload means nothing is playing. Controls: `send <id>`
(2 toggle, 4 next, 5 previous), `seek <microseconds>`.

Chain: adapter → distributed notifications (Music, Spotify) → "No media detected".

## Testing

XCTest for `NotchState`, `HoverIntent`, `ScreenGeometry`, `NowPlayingDecoder`, `ClipboardFilter`,
`ShelfStore` pruning, `CostReceipt` formatting. Hardware behaviour → `docs/VERIFY-ON-MAC.md`.
