# 04 — QA Checklist

Every release must pass this. The matrix is built directly from the failures users report about
competing apps, so each row maps to a real one-star review somewhere.

## Performance (the wedge — run first, fail fast)

- [ ] 2-hour idle soak, panel collapsed: average CPU **≤ 0.1%**
- [ ] Idle wakeups near zero with media stopped and clipboard off
- [ ] RSS **< 80 MB** after 24 hours
- [ ] Activity Monitor Energy Impact reads effectively zero when collapsed
- [ ] With clipboard enabled: cost measured, documented, and shown in settings
- [ ] No helper processes left behind after quit (`pgrep -fl perl` and friends)
- [ ] All timers and observers confirmed removed when a module is disabled

## Display matrix

Test each combination. "Correct" means: panel present where expected, absent where not, right
size, right position, no duplicates, no orphans.

| Scenario | Built-in | 1 external | 2 external | Mixed HiDPI/non-HiDPI |
|---|---|---|---|---|
| Cold launch | ☐ | ☐ | ☐ | ☐ |
| Hot-plug display | ☐ | ☐ | ☐ | ☐ |
| Unplug display while panel open | ☐ | ☐ | ☐ | ☐ |
| Change resolution | ☐ | ☐ | ☐ | ☐ |
| Change scaling | ☐ | ☐ | ☐ | ☐ |
| Rearrange displays | ☐ | ☐ | ☐ | ☐ |
| Change primary display | ☐ | ☐ | ☐ | ☐ |
| Clamshell (lid closed, external only) | — | ☐ | ☐ | ☐ |
| Rapid plug/unplug ×10 | ☐ | ☐ | ☐ | ☐ |

Also:
- [ ] Non-notched Mac (Air M1 / Intel) — simulated pill looks deliberate
- [ ] Notched Mac with a non-notched external — correct on both
- [ ] Sidecar / iPad as display
- [ ] AirPlay display

## Window behaviour

- [ ] Visible on every Space
- [ ] Correctly suppressed under a fullscreen app on the same display
- [ ] Still works on other displays while one display has a fullscreen app
- [ ] Stage Manager on: no layout corruption
- [ ] Mission Control: panel does not appear as a stray window
- [ ] App Exposé and Spaces switching: no flicker or duplication
- [ ] Does not appear in screenshots of other windows unexpectedly
- [ ] Does not appear on the login window or lock screen
- [ ] Menu bar auto-hide enabled: still correct
- [ ] Dark mode / light mode / appearance change while open
- [ ] Increase contrast and reduce transparency accessibility settings

## Sleep, wake, and sessions

- [ ] Lid close → open (built-in only)
- [ ] Lid close → open (docked)
- [ ] Display sleep → wake
- [ ] System sleep → wake
- [ ] Fast user switching away and back
- [ ] Lock screen → unlock
- [ ] Reboot with launch-at-login enabled
- [ ] 24-hour uptime: still responsive, no drift, no leak

## Hover behaviour (the most-complained-about interaction)

- [ ] Throw the pointer at the menu bar 20× — panel never opens
- [ ] Click a menu bar item near the notch — no interference
- [ ] Deliberate hover opens every time, within the configured delay
- [ ] Pointer skimming the edge does not cause flicker
- [ ] Moving out and back quickly does not double-animate
- [ ] Changing hover delay takes effect immediately
- [ ] Dead zone toggle behaves as documented
- [ ] Clicks outside the visible shape pass through — verify against a browser tab strip and a
      Finder window title bar

## Now Playing

- [ ] Apple Music, Spotify, Safari/YouTube, Chrome, VLC, IINA, Podcasts
- [ ] Track change updates without reopening the panel
- [ ] Artwork loads and is cached; no flicker on change
- [ ] Transport controls work in each app that supports them
- [ ] Pause/stop → panel reflects it
- [ ] Two media apps playing → sensible, stable choice of which to show
- [ ] Helper killed manually → restarts; killed repeatedly → falls back cleanly
- [ ] Scripting fallback path works and its permission prompt is explained first
- [ ] No media playing → honest empty state, never a spinner
- [ ] **Verified on macOS 14.x, 15.4+, and 26.x separately**

## File shelf

- [ ] Drag from Finder, Safari, Mail, Photos, Preview, Slack
- [ ] Drag out to Finder, Mail compose, Slack, a browser upload field
- [ ] Original file deleted → shelf item still valid
- [ ] Original file moved → shelf item still valid
- [ ] 50-file drop does not block the UI
- [ ] Very large file (>1 GB) handled without freezing
- [ ] Pinned items survive Clear all
- [ ] Cap enforcement prunes oldest first
- [ ] Multi-select drag out
- [ ] Share / AirDrop from the context menu

## Clipboard

- [ ] Text, rich text, image, file, multiple-file copies all captured
- [ ] Password-manager copy produces **no** entry
- [ ] Blocklisted app produces no entry
- [ ] Search filters correctly; keyboard navigation works
- [ ] Paste inserts into the frontmost app correctly
- [ ] History survives relaunch; caps enforced
- [ ] Pause capture actually stops the timer (verify with `bench.sh`)
- [ ] **macOS 15.4+ pasteboard alert behaviour confirmed and documented**

## Permissions

- [ ] Fresh install on a clean user account — every prompt is explained before it appears
- [ ] Denying every permission still leaves a usable app
- [ ] Granting later is detected without relaunch
- [ ] Revoking in System Settings is detected on next wake/activate
- [ ] No permission is requested for a disabled module
- [ ] No repeated prompting after a grant (the named competitor bug)

## Install and update

- [ ] Clean machine install: `spctl -a -vvv` passes, no Gatekeeper warning
- [ ] Notarisation ticket stapled
- [ ] Sparkle update installs end-to-end and relaunches correctly
- [ ] Update while the panel is open
- [ ] Uninstall leaves no running processes and no login item
- [ ] Reinstall restores preferences correctly

## Licensing

- [ ] Trial countdown accurate; expiry is clear and non-hostile
- [ ] Activation succeeds and persists
- [ ] Offline grace period works
- [ ] Device limit enforced with a clear message
- [ ] Deactivation frees a seat
- [ ] Free-tier gates are visible before the user commits to an action

## Localisation and accessibility

- [ ] VoiceOver can reach and describe every control
- [ ] Full keyboard navigation of the expanded panel
- [ ] Reduce motion → cross-fade instead of spring
- [ ] Increase contrast respected
- [ ] Dynamic type / larger text does not break layout
- [ ] No hard-coded strings (`genstrings` finds everything)

## Pre-release smoke test (10 minutes, every build)

1. Launch, hover, expand, collapse.
2. Play music, verify panel, change track.
3. Drop a file in, drag it out.
4. Copy something, find it in history.
5. Plug in a monitor, unplug it.
6. Sleep, wake.
7. Check Activity Monitor: CPU and energy at idle.
