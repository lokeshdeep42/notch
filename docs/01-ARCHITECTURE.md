# 01 — Architecture

## Guiding principle

**Event-driven, not polled.** Almost every performance failure in this category comes from apps
that run a 0.5s timer to ask the system "anything new?" We subscribe to notifications instead, and
where no notification exists we either poll only while visible, or we make the feature opt-in and
measure its cost.

## Module layout

Swift Package with a thin app target on top. This keeps modules genuinely separable and makes
unit testing possible without launching the app.

```
Sill/
├── CLAUDE.md
├── README.md
├── docs/
├── project.yml                 # XcodeGen — keeps the project file diffable
├── Sill.xcodeproj              # generated, gitignored
├── App/
│   ├── SillApp.swift           # @main, NSApplicationDelegateAdaptor
│   ├── AppDelegate.swift       # lifecycle, menu bar item, wiring
│   └── Info.plist              # LSUIElement = YES
├── Sources/
│   ├── NotchCore/              # the heart — no feature knowledge lives here
│   │   ├── NotchPanel.swift            # the NSPanel subclass
│   │   ├── NotchPanelController.swift  # one controller per display
│   │   ├── NotchWindowManager.swift    # owns controllers, reacts to display changes
│   │   ├── ScreenGeometry.swift        # notch detection + frame maths
│   │   ├── NotchShape.swift            # the rounded-cutout Shape
│   │   ├── NotchState.swift            # the state machine
│   │   ├── HoverMonitor.swift          # tracking areas + debounce
│   │   └── NotchRootView.swift         # SwiftUI host, routes to feature views
│   ├── Features/
│   │   ├── NowPlaying/
│   │   ├── Shelf/
│   │   ├── Clipboard/
│   │   └── PowerStatus/
│   ├── Services/
│   │   ├── Preferences.swift
│   │   ├── PermissionService.swift
│   │   ├── LaunchAtLogin.swift
│   │   ├── LicenseService.swift
│   │   ├── UpdateService.swift         # Sparkle wrapper
│   │   ├── Branding.swift              # app name in exactly one place
│   │   └── Log.swift                   # os.Logger categories
│   ├── DesignSystem/           # colours, typography, spring constants, materials
│   └── SettingsUI/             # the preferences window + onboarding
├── Tests/
├── Vendor/
│   └── mediaremote-adapter/    # bundled helper, see 02-TECHNICAL-REFERENCE
└── Scripts/
    ├── build.sh  test.sh  sign.sh  notarize.sh  release.sh  bench.sh
```

> **As built (2026-09-19):** SwiftPM only — `Package.swift` + `Scripts/build.sh` instead of
> XcodeGen; `App/SillMain.swift` (`@main`) instead of `SillApp.swift`; feature targets are
> `FeatureNowPlaying`, `FeatureShelf`, `FeatureClipboard`, `FeaturePower`. Features plug into
> `NotchCore` through the `NotchModule` protocol, so `NotchRootView` never names a feature.
> See docs/ADR.md.

**Dependency rule:** `Features/*` may import `NotchCore`, `Services`, `DesignSystem`. They may
**not** import each other. `NotchCore` imports nothing but `Services` and `DesignSystem`.

## The notch state machine

`NotchState` is the single source of truth for what the panel is doing. Keep it small and total —
every transition explicit. Ambiguous hover behaviour is the number-one UX complaint in this
category, and it always comes from ad-hoc booleans.

```
              ┌──────────────────────────────────────────┐
              │                                          │
              ▼                                          │
         ┌─────────┐   pointer enters   ┌──────────┐     │
         │ closed  │ ─────────────────► │ pending  │     │
         └─────────┘   (start enter     └──────────┘     │
              ▲          timer)              │           │
              │                              │ enter     │
              │                              │ delay     │
              │  exit delay elapsed          │ elapsed   │
              │                              ▼           │
         ┌─────────┐  pointer leaves   ┌──────────┐      │
         │ closing │ ◄──────────────── │   open   │      │
         └─────────┘                   └──────────┘      │
              │  pointer re-enters                       │
              └──────────────────────────────────────────┘

  Additional states:
    peek(Event)   — transient, uninterruptible-for-N-seconds notification
                    (track change, battery plugged in). Returns to closed.
    suppressed    — a fullscreen app owns this display, or the user disabled
                    this display, or the screen is locked. No rendering at all.
```

Rules:
- `pending → open` only after the **enter delay** (default 180 ms, user-tunable 0–800 ms).
- `closing → closed` only after the **exit delay** (default 250 ms). Re-entering cancels it.
  This stops the flicker users complain about when the pointer skims the edge.
- A **dead-zone**: the hover region is inset from the very top few pixels of the screen so that
  throwing the pointer at the menu bar does not open the panel. Tunable, default on.
- `peek` never interrupts `open`. If the user has the panel open, a track change just updates
  content in place.
- `suppressed` tears the panel down entirely (no window, no observers) rather than hiding it.
  A hidden-but-alive window is how competitors end up burning CPU in fullscreen.

## One controller per display

`NotchWindowManager` owns a `[CGDirectDisplayID: NotchPanelController]`. On
`NSApplication.didChangeScreenParametersNotification` it diffs the current screen set against the
live controllers and creates/destroys accordingly. This is the single most important design
decision for the multi-display wedge: **never** try to move one window between screens.

Per-display user preference: `on built-in only` (default) / `all displays` / `chosen displays`.

## Performance architecture

### Event sources — what we subscribe to instead of polling

| Data | Mechanism | Polling? |
|---|---|---|
| Hover | `NSTrackingArea` on the panel content view | No |
| Display topology | `NSApplication.didChangeScreenParametersNotification` | No |
| Sleep / wake | `NSWorkspace.shared.notificationCenter` — `didWake`, `screensDidSleep`, `screensDidWake`, `sessionDidResignActive` | No |
| Frontmost app / fullscreen | `NSWorkspace.didActivateApplicationNotification` + a check on activation | No |
| Battery & charging | `IOPSNotificationCreateRunLoopSource` (IOKit power-source callback) | No |
| Now Playing | long-lived adapter process streaming newline-delimited JSON | No |
| Fullscreen apps | `activeSpaceDidChange` + app activation → one `CGWindowListCopyWindowInfo` bounds check (no permission) | No |
| Screen lock | `com.apple.screenIsLocked` / `screenIsUnlocked` distributed notifications | No |
| File drag approaching the notch | Global `leftMouseDown/Dragged/Up` monitors — silent unless a mouse button is held | No |
| Music/Spotify fallback | Distributed notifications | No |
| Clipboard | **`NSPasteboard.changeCount` polling — the one unavoidable poll** | Yes, gated |

### The clipboard exception

macOS provides no change notification for the general pasteboard. Rules to keep it honest:

- Clipboard history is **off by default**; the user opts in.
- When on, poll `changeCount` at **1.0 s** (not 0.2 s). Reading only the integer `changeCount` is
  very cheap; only read the actual pasteboard contents when the count changed.
- **Suspend the timer entirely** when the display sleeps, the session is inactive (fast user
  switching / lock), or the device has been idle beyond a threshold.
- Measure the cost and put the number in the settings UI next to the toggle. Turning the cost of
  a feature into a visible, honest number is exactly on-brand for this product.
- See `docs/02-TECHNICAL-REFERENCE.md` §Clipboard for the macOS 15.4 pasteboard-privacy alert,
  which must be tested first-hand.

### Rendering

- The panel window's frame is **fixed at the maximum expanded size** and never resized during
  animation. Resizing an `NSWindow` every frame is the main cause of the stutter users report.
  The expansion is a pure SwiftUI layout animation inside a stable window.
- Because the window is large and transparent, the content view must override `hitTest(_:)` to
  return `nil` for points outside the currently active shape. Otherwise the app silently eats
  clicks across a wide strip of the screen — a bug users will notice immediately and blame on
  something else.
- Nothing renders while `closed`: the root view returns an empty shape, and per-feature view
  models are not subscribed. Subscriptions start on `pending`, not on launch.
- Artwork and thumbnails are downsampled once and cached; never hand a full-size `NSImage` to
  SwiftUI on every frame.

### Instrumentation (build this in Milestone 0, not later)

- `Scripts/bench.sh` — launches the app, leaves it idle for 120 s, samples with `powermetrics`
  and `top`, prints average CPU %, idle wakeups, and RSS. Run it on every milestone.
- `os_signpost` intervals around expand/collapse so Instruments shows frame cost directly.
- A hidden debug overlay (behind a defaults flag) showing current state, active display ID,
  frames-per-second during animation, and live wakeup count.

## State and persistence

- **Preferences:** `UserDefaults` via a typed `Preferences` object with `@AppStorage`-style
  property wrappers. Small, no migration burden.
- **Shelf items:** files are **copied** into `~/Library/Application Support/<bundle>/Shelf/`
  on drop, with a JSON manifest. Never store only a bookmark to the original — users move and
  delete originals, and a shelf full of dead links is a known complaint.
- **Clipboard history:** SQLite (GRDB) or a capped JSON store. Images and files stored as blobs
  on disk with a manifest row. Encrypt at rest if it is cheap to do; at minimum set restrictive
  file permissions and exclude from Time Machine and Spotlight.
- Both stores must be **capped by count and by bytes**, with pruning on launch.

## Concurrency

- Everything touching AppKit or SwiftUI is `@MainActor`.
- The Now Playing adapter's stdout is read on a background task and hops to the main actor to
  publish.
- Shelf file copies and thumbnail generation happen off the main actor.
- No `DispatchQueue.main.async` sprinkling; use structured concurrency and actor isolation.

## Dependencies (approved list)

| Dependency | Licence | Purpose | Notes |
|---|---|---|---|
| Sparkle 2.x | MIT | Auto-updates | SPM, EdDSA appcast signing |
| `ungive/mediaremote-adapter` | check before bundling | Now Playing post-15.4 | Bundled helper, not linked |
| GRDB (optional) | MIT | Clipboard store | Only if a plain JSON store proves inadequate |

Anything else requires explicit approval. In particular: **do not** pull in a large UI framework,
an analytics SDK, or a crash reporter that phones home by default. Privacy is part of the pitch.

`DynamicNotchKit` (MIT) is worth reading and may be added as a dependency during the Milestone 0
spike to prove the concept quickly — but the intent is to own this code, because the window
behaviour *is* the product.
