# Sill

**The notch app that disappears.** A macOS menu-bar utility that turns the MacBook notch into a
small hub — now playing, a file shelf, clipboard history, battery — and costs essentially nothing
when you're not using it. It also shows you that cost, live, in its own panel.

> "Sill" is a working name. See [Naming](#naming).

![CI](https://github.com/lokeshdeep42/notch/actions/workflows/ci.yml/badge.svg)

## Status

All v1 features except licensing are implemented. Everything compiles with **zero warnings** and
passes its unit tests on GitHub's macOS 15 runners, but **nothing has run on real hardware yet**.
The next step is [`docs/VERIFY-ON-MAC.md`](docs/VERIFY-ON-MAC.md).

## What makes it different

| | |
|---|---|
| **Intent-aware hover** | Opens when your pointer *settles* in the notch, not just after a timer. Throw the pointer at the menu bar and it stays shut. |
| **Live cost receipt** | The panel footer shows Sill's own CPU, wakeups and memory since launch, read from the kernel. |
| **Magnetic drop zone** | Drag a file toward the top of the screen and the notch leans toward it, then opens into the shelf. |
| **Physical motion** | One shape morphs out of the hardware notch on interruptible springs; content settles in behind it. Reduce Motion gets a cross-fade. |
| **Honest idle** | No repeating timers while collapsed. The only poll (clipboard) is opt-in and stops when your Mac sleeps or locks. |
| **Multi-display** | One panel per display, rebuilt on every plug, unplug, resolution change and wake. A pill on displays without a notch. |
| **Minimum permissions** | None to run. Automation is asked for only if you use playback controls without the Now Playing helper — and it's explained first. |

## Build and run

Requires macOS 14+, Xcode 15+ (or Command Line Tools), and `cmake` for the Now Playing helper.

```bash
Scripts/fetch-adapter.sh   # builds ungive/mediaremote-adapter v0.7.7 (BSD-3) into Vendor/
Scripts/build.sh           # → build/Sill.app (ad-hoc signed)
Scripts/test.sh            # unit tests
Scripts/run.sh             # debug build + launch
Scripts/bench.sh 120       # idle CPU / wakeups / RSS for Sill and its helper
```

Every push to `main` runs the same steps on CI and uploads a ready-to-run `Sill.app` artifact.

## Layout

```
App/                       entry point, app delegate, status item, Info.plist
Sources/DesignSystem/      springs, palette, type, metrics
Sources/Services/          preferences, logging, branding, cost receipt, launch at login, permissions
Sources/NotchCore/         state machine, hover intent, geometry, panel, window manager, drag magnet
Sources/Features/*/        NowPlaying · Shelf · Clipboard · Power — never import each other
Sources/SettingsUI/        settings window and onboarding
Tests/SillTests/           unit tests for every piece of pure logic
docs/                      spec, architecture, technical reference, build plan, QA, release, ADR
```

Start with [`CLAUDE.md`](CLAUDE.md), then [`docs/00-PRODUCT-SPEC.md`](docs/00-PRODUCT-SPEC.md) and
[`docs/01-ARCHITECTURE.md`](docs/01-ARCHITECTURE.md). Decisions and deviations from the original
spec are in [`docs/ADR.md`](docs/ADR.md).

## Naming

"Sill" is a placeholder, kept in one place: `Sources/Services/Branding.swift` (plus the bundle id in
`App/Info.plist`). Candidates before a trademark check:

- **Lintel**: the beam across the top of a window opening. The notch is the top of your screen, and
  it pairs with "Sill".
- **Hush**: quiet, costs nothing, disappears.
- **Eave**: architectural, hangs over the top edge.

Never "Dynamic Island" (Apple's trademark), and avoid "Notch-" prefixes.

## Licences

Closed source. Bundles [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
(BSD-3-Clause, credited in About). No GPL code; `boring.notch` and `mew-notch` were read for
behaviour only.
