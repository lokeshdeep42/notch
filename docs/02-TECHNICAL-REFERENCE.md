# 02 — Technical Reference

Everything here was assembled from research and from reading open-source implementations. It is a
strong starting point, **not** verified against a running build. Where something is marked
**⚠ VERIFY**, write a five-line probe and confirm on the actual OS before building on it, then
update this document.

Target: **macOS 14.0+** (Sonoma). Test on 14.x, 15.4+, and 26.x (Tahoe) — behaviour differs.

---

## 1. App shell

### Agent app
`Info.plist`:
```xml
<key>LSUIElement</key><true/>
```
No Dock icon, no main menu. The app lives in the menu bar plus the notch panel.

### Launch at login (macOS 13+)
```swift
import ServiceManagement

try SMAppService.mainApp.register()     // enable
try SMAppService.mainApp.unregister()   // disable
SMAppService.mainApp.status             // .enabled / .notRegistered / .requiresApproval
```
Handle `.requiresApproval` by pointing the user at Login Items in System Settings. Users complain
about launch-at-login silently failing in competitors — surface the real status in settings rather
than a bare toggle.

### Menu bar item
`NSStatusItem` with `NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)`.
Menu: Settings, Pause (suppress the panel), Check for Updates, Quit. boring.notch has an open
issue where users could not find settings or quit — do not repeat that.

---

## 2. Notch geometry

### Detection
```swift
extension NSScreen {
    var hasNotch: Bool { safeAreaInsets.top > 0 }          // macOS 12+

    /// Physical cutout size in points, nil on non-notched screens.
    var notchSize: CGSize? {
        guard let left = auxiliaryTopLeftArea,              // macOS 12+
              let right = auxiliaryTopRightArea,
              hasNotch else { return nil }
        return CGSize(width: frame.width - left.width - right.width,
                      height: safeAreaInsets.top)
    }
}
```

Reference measurements (research-sourced, **⚠ VERIFY** on real hardware):
- 16-inch: roughly **220 × 38 pt**
- 14-inch: roughly **185 × 32 pt**
- Notch height equals menu-bar height at default scaling; it changes with display scaling, so
  never hard-code it.

### Non-notched Macs and external displays
Render a **simulated pill** flush against the top edge of the screen, centred, using a default
size close to the 14-inch notch. Give the user a size control. Competitors that handle this badly
get "doesn't work on my monitor" reviews.

### Coordinate system trap
`NSScreen.frame` is in a bottom-left origin, global coordinate space where the primary display's
origin is `(0,0)`. Secondary displays can have **negative** origins. Compute the panel frame from
`screen.frame`, never from `NSScreen.main`, and never assume `screens[0]`.

### Display reconfiguration
```swift
NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
) { _ in manager.reconcileDisplays() }
```
This fires for: plug/unplug, resolution change, scaling change, arrangement change, and
(on some machines) display sleep. Debounce it — it can fire several times in a burst.
`reconcileDisplays()` must be idempotent.

Also observe, via `NSWorkspace.shared.notificationCenter`:
`didWakeNotification`, `screensDidSleepNotification`, `screensDidWakeNotification`,
`sessionDidResignActiveNotification`, `sessionDidBecomeActiveNotification`.
Sleep/wake reliability is a named complaint against several competitors.

---

## 3. The panel window

```swift
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel      = true
        level                = .statusBar        // see note below
        isOpaque             = false
        backgroundColor      = .clear
        hasShadow            = false
        isMovableByWindowBackground = false
        isMovable            = false
        hidesOnDeactivate    = false
        ignoresMouseEvents   = false             // hit-testing handled in the content view
        collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                .stationary, .ignoresCycle]
        // macOS 13+: also consider .canJoinAllApplications for Stage Manager
    }

    override var canBecomeKey: Bool { true }     // needed for clipboard search field
    override var canBecomeMain: Bool { false }
}
```

**Window level.** `.statusBar` (25) sits at the menu-bar layer and, importantly, is not clamped by
`constrainFrameRect(_:to:)`, so the window can sit flush over the notch. Some implementations use
`NSMainMenuWindowLevel + 3` (27) to sit just above the menu bar. **⚠ VERIFY** which value gives
correct stacking against the menu bar, Spotlight, and notification banners on your target OS
versions, and record the choice in `docs/ADR.md`.

**Re-assert `collectionBehavior` on every reveal.** macOS is known to silently drop
`.canJoinAllSpaces` when windows are re-ordered. Set it again in `orderFront`.

**Frame stability.** Set the frame once, to the maximum expanded bounds, anchored to the top
centre of its screen. Do not animate the frame.

### Hit-testing (critical)
Because the window is wide and transparent, override hit-testing in the content view so clicks
outside the visible shape pass through to whatever is underneath:

```swift
final class PassthroughView: NSView {
    /// Updated by the view model whenever the panel's visible shape changes.
    var activeRect: NSRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        activeRect.contains(convert(point, from: nil)) ? super.hitTest(point) : nil
    }
}
```
Get this wrong and the app swallows clicks across the top of the screen. It is the kind of bug
users never diagnose correctly — they just uninstall.

---

## 4. Hover detection

**Use `NSTrackingArea`, not a global event tap.** A `CGEventTap` requires Accessibility
permission and costs battery — both directly against the product thesis.

```swift
let area = NSTrackingArea(
    rect: hoverRect,                                   // the collapsed pill + a small margin
    options: [.mouseEnteredAndExited, .activeAlways, .mouseMoved],
    owner: self, userInfo: nil)
contentView.addTrackingArea(area)
```

- `.activeAlways` is required — the app is never frontmost.
- Rebuild the tracking area whenever the panel's geometry changes.
- **Dead zone:** inset the hover rect a few points down from `screen.frame.maxY` so a fast throw
  toward the menu bar does not clip the region. Make the inset a preference.
- **Debounce:** enter-delay ~180 ms, exit-delay ~250 ms, both tunable. Cancel the pending timer on
  the opposite event. Use `Task` with `Task.sleep` and cancellation rather than `Timer`.

If tracking areas prove unreliable over the notch (**⚠ VERIFY** — the cutout region behaves
unusually for some event types), the fallback is `NSEvent.addGlobalMonitorForEvents(matching:
.mouseMoved)`, which needs no special permission but delivers events continuously. If you must use
it, throttle hard and disable it while `suppressed`. Record which approach won in `docs/ADR.md`.

---

## 5. Animation

Target: match Alcove's feel, which is the category's quality benchmark.

```swift
enum Motion {
    static let expand   = Animation.spring(response: 0.35, dampingFraction: 0.78)
    static let collapse = Animation.spring(response: 0.30, dampingFraction: 0.85)
    static let content  = Animation.spring(response: 0.28, dampingFraction: 0.82)
}
```
These are a starting point; tune by feel on real hardware. Slightly overdamped on collapse feels
more "Apple" than a bouncy return.

- Animate layout inside a fixed-size window. Do not animate the `NSWindow` frame.
- `matchedGeometryEffect` for elements that persist across states (artwork thumbnail →
  large artwork). Use sparingly; it is a common source of glitches when identities change.
- Stagger content fade-in ~40–60 ms behind the shape expansion so the panel reads as opening
  rather than popping.
- `.drawingGroup()` only if profiling shows it helps; it can hurt with materials.
- Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` — cross-fade instead.

### Notch shape
A rounded rect whose **top corners curve outward** to meet the screen edge, and whose bottom
corners are conventionally rounded. Build it as a custom `Shape` with explicit arcs:

- top-left: outward arc, radius ~6 pt
- bottom-left / bottom-right: inward arc, radius ~12 pt collapsed, ~18–22 pt expanded
- animate the radii along with the size

`DynamicNotchKit`'s `NotchShape.swift` (MIT) is a good reference implementation to study.

---

## 6. Now Playing — the hard one

### The problem
`MediaRemote.framework` is private. **Since macOS 15.4, `mediaremoted` enforces entitlement
checks**, so unentitled third-party apps get empty now-playing payloads. This broke every notch
app in the category and is still the most common "it stopped working" complaint.

### The approach: `ungive/mediaremote-adapter`
Bundles a Perl script plus `MediaRemoteAdapter.framework`. The script is executed by
`/usr/bin/perl`, which is Apple-signed (`com.apple.perl`) and already entitled, so MediaRemote
answers it. The adapter streams now-playing state as newline-delimited JSON on stdout.

- Does **not** require disabling SIP.
- Reported working on macOS 15.4+ and macOS 26.x. **⚠ VERIFY** on your target versions.
- **Check the licence before bundling** and record it in `docs/ADR.md`.

Confirmed 2026-09-19: **BSD-3-Clause**, pinned to v0.7.7. Use `stream --micros --debounce=100`;
lines are `{"type":"data","diff":bool,"payload":{…}}` — diffs merge into the last full payload and
`null` removes a key. Commands: `send 2` (toggle), `send 4` (next), `send 5` (previous),
`seek <microseconds>`.

Implementation sketch:
```swift
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
proc.arguments = [scriptPath, frameworkPath, "stream"]
// read stdout line-by-line on a background task, decode JSON, publish on the main actor
```

Requirements:
- Supervise the process: restart with exponential backoff if it dies; give up after N attempts and
  fall back.
- **Terminate it when the panel is `suppressed` or the media feature is off.** A stray helper
  process is exactly the kind of thing that shows up in someone's battery report.
- Ship the helper inside the app bundle and make sure it survives signing and notarisation
  (it needs its own signature; see `docs/05-RELEASE.md`).

### Fallback chain
1. Adapter stream (full fidelity, artwork, all apps).
2. **ScriptingBridge / AppleScript** for Music and Spotify specifically — gives title, artist,
   album, and play state but **no artwork** and requires polling.
   > **Corrected 2026-09-19:** Music and Spotify post distributed notifications
   > (`com.apple.Music.playerInfo`, `com.spotify.client.PlaybackStateChanged`) carrying title, artist,
   > album and state. Listening needs no permission and no polling; Apple Events are only used to
   > *control* playback. See `Sources/Features/NowPlaying/DistributedMediaSource.swift` and docs/ADR.md. Needs Apple Events permission
   (`NSAppleEventsUsageDescription`), which prompts the user. Only attempt this if the adapter
   has failed and only for apps that are actually running.
3. Honest empty state: "No media detected" with a link to a help page. Never an infinite spinner.

### Controls
Play/pause/next/previous through the adapter's command interface where available. **⚠ VERIFY**
write/command support on macOS 26.x. If commands are unavailable, hide the transport controls
rather than showing dead buttons.

---

## 7. File shelf

### Accepting drops
SwiftUI `.dropDestination(for: URL.self)` (macOS 13+) or `.onDrop(of:isTargeted:perform:)` with
`NSItemProvider`. Accept `.fileURL`, `.image`, `.text`.

Critical behaviours:
- **Copy the file** into `~/Library/Application Support/<bundle>/Shelf/<uuid>/` immediately.
  Do not keep a reference to the original. Users move and delete originals.
- Generate a thumbnail with `QLThumbnailGenerator` off the main actor; cache it.
- The panel must **auto-expand into drop mode** when a drag enters the notch region while
  collapsed — this is the shelf's signature interaction and the most-loved feature in NotchNook.
  Drag-tracking is separate from mouse-hover tracking; register the window as a drag destination.

### Dragging files back out
> **Changed 2026-09-19:** shelf items are already real files in our store, so the drag source
> writes their `NSURL`s with a `.copy`-only operation mask instead of `NSFilePromiseProvider`
> (browser upload fields and Slack accept URLs more reliably than promises). Incoming promises from
> Photos/Mail are still received with `NSFilePromiseReceiver`. See docs/ADR.md.

SwiftUI's `.draggable` cannot produce file promises. Wrap an `NSView` in `NSViewRepresentable` and
implement a drag source with `NSFilePromiseProvider`:

```swift
let provider = NSFilePromiseProvider(fileType: uti, delegate: self)
let item = NSDraggingItem(pasteboardWriter: provider)
item.setDraggingFrame(bounds, contents: thumbnailImage)
beginDraggingSession(with: [item], event: event, source: self)
```
Implement `filePromiseProvider(_:fileNameForType:)` and
`filePromiseProvider(_:writePromiseTo:completionHandler:)`. `NotchDrop` (MIT) is a clean reference.

### Shelf features
Pin (survives "Clear all"), multi-select, right-click menu (Reveal in Finder, Share/AirDrop via
`NSSharingServicePicker`, Remove), and a byte/count cap with oldest-first pruning.

---

## 8. Clipboard history

### Detection
No notification exists. Poll `NSPasteboard.general.changeCount` at 1.0 s and only read contents
when it changes. Gate the timer as described in `docs/01-ARCHITECTURE.md` §Performance.

### macOS 15.4 pasteboard privacy — **⚠ VERIFY FIRST**
macOS 15.4 introduced an alert when an app reads the general pasteboard **without user
interaction**, plus an `accessBehavior` property and `detectPatterns(for:)` for inspecting content
without reading it. Reported testing suggests reading `changeCount` alone does not trigger the
alert, but **the poll-then-read pattern must be tested with a real signed app bundle** before
committing to the design.

Enable the developer preview to test the behaviour early:
```bash
defaults write <your.bundle.id> EnablePasteboardPrivacyDeveloperPreview -bool yes
```

If the alert does fire on read, options are: `detectPatterns(for:)` to classify without reading,
requiring an explicit user gesture (hotkey) to capture, or dropping automatic capture and offering
manual "save to clipboard history".

### Safety rules
- Skip entries carrying `org.nspasteboard.ConcealedType` (the convention password managers use).
- Skip entries from a user-configurable app blocklist.
- Cap history by count **and** bytes; prune on launch.
- Provide an obvious "clear history" and a "pause capture" control.

---

## 9. Power status

Event-driven, no polling:
```swift
let source = IOPSNotificationCreateRunLoopSource({ _ in /* refresh */ }, nil)?.takeRetainedValue()
CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
```
Read with `IOPSCopyPowerSourcesInfo()` / `IOPSCopyPowerSourcesList()` for percentage, charging
state, and time remaining. For cycle count and battery health, match the `AppleSmartBattery`
IOService.

CPU / memory / disk stats (`host_statistics64`, `host_processor_info`) are **v2** — and when they
arrive, they poll **only while the panel is open**.

---

## 10. Permissions map

| Permission | Needed for | When to ask | v1? |
|---|---|---|---|
| Apple Events (Automation) | Music/Spotify scripting fallback only | Only if the adapter fails and the user opts in | Yes, conditional |
| Calendar (EventKit) | Next-event widget | On first use | No (v2) |
| Accessibility | Global event tap, window control | Only if tracking areas prove insufficient | Avoid |
| Input Monitoring | Global hotkeys | Only if hotkeys ship | Avoid in v1 |
| Screen Recording | Camera mirror, capture | — | **Out of scope** |
| Notifications | Update/alert banners | On first relevant event | Optional |

Onboarding rules (this fixes a named competitor complaint):
- Explain in one sentence why the permission is needed, before the system prompt.
- Deep-link to the exact pane:
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- **Re-check the actual grant status** on wake and on activation. The "it keeps asking even though
  I granted it" bug comes from caching a stale answer.
- Never block app launch on a permission.

---

## 11. Reference implementations

| Project | Licence | Use it for |
|---|---|---|
| `MrKai77/DynamicNotchKit` | **MIT** | Notch window, `NotchShape`, `NSScreen` extensions. Safe to depend on or vendor. Best starting point. |
| `Lakr233/NotchDrop` | **MIT** | File shelf, drag-out, storage model. Safe to adapt. |
| `Notchmeister` (Iconfactory) | **BSD-3** | Notch visual effects. Safe. |
| `ungive/mediaremote-adapter` | check | The Now Playing bridge. Verify licence before bundling. |
| `TheBoredTeam/boring.notch` | **GPL-3.0** | Behaviour and its issue tracker (a free feature-request backlog). **Never copy code.** |
| `monuk7735/mew-notch` | **GPLv3** | Hover-delay UX ideas. **Never copy code.** |

The GPL distinction is not pedantry — copying from those two projects into a closed-source paid
app would be a licence violation.

---

## 12. Known traps, collected

1. `.canJoinAllSpaces` silently dropped on window re-order → re-assert on every `orderFront`.
2. Transparent window eating clicks → override `hitTest`.
3. Animating the `NSWindow` frame → stutter. Fixed frame, animate content.
4. `NSScreen.main` is "the screen with the key window", **not** the built-in display.
5. Negative screen origins on secondary displays.
6. `didChangeScreenParameters` firing in bursts → debounce, and make reconciliation idempotent.
7. Helper processes surviving quit → terminate in `applicationWillTerminate` and on suppress.
8. Permission status cached at launch → re-check on wake/activate.
9. Shelf items referencing moved originals → copy on drop.
10. Media detected only at launch (a real competitor bug) → subscribe to a stream, don't snapshot.
