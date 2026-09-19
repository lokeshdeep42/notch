# Verify on a real Mac

Everything in this repo compiles and passes its unit tests on GitHub's macOS 15 runners, but
**none of it has run on real hardware yet**. This is the checklist for the first session on a
MacBook. It is ordered by risk: if section 1 or 2 fails, stop and report — those are Milestone 0,
the part the whole product depends on.

Time needed: about 45 minutes for sections 0–6, longer with an external monitor.

---

## 0. Get the app running (5 min)

**Option A — download (no Xcode needed).**
1. Open <https://github.com/lokeshdeep42/notch/actions>, click the latest green run, and download
   the **Sill-app** artifact (you need to be signed in to GitHub). Unzip it twice until you have
   `Sill.app`.
2. It is ad-hoc signed, not notarised, so macOS will quarantine it. In Terminal:
   ```bash
   xattr -dr com.apple.quarantine ~/Downloads/Sill.app
   mv ~/Downloads/Sill.app /Applications/
   open /Applications/Sill.app
   ```

**Option B — build from source.** Needs Xcode 15+ (or Command Line Tools) and `brew install cmake`.
```bash
git clone https://github.com/lokeshdeep42/notch.git && cd notch
Scripts/fetch-adapter.sh      # Now Playing helper
Scripts/build.sh && Scripts/test.sh
open build/Sill.app
```

**Watch the logs while testing** (keep this running in a second Terminal window):
```bash
log stream --predicate 'subsystem == "app.sill.Sill"' --level debug
```

Turn on the debug overlay (shows state, display ID and FPS in the open panel's footer):
```bash
defaults write app.sill.Sill DebugOverlay -bool YES   # then quit and reopen Sill
```

- [ ] App launches, no Dock icon, a menu bar icon appears (a small rectangle).
- [ ] The onboarding window appears on first launch; Skip closes it for good.
- [ ] Menu bar icon → Quit works. `pgrep -fl "Sill|mediaremote"` then prints nothing.

## 1. Milestone 0 — does the panel exist and behave? (10 min)

- [ ] Hover the notch: it grows a few points instantly, then opens into the panel.
- [ ] The open panel's top edge merges with the hardware notch (no visible seam or gap).
- [ ] Move away: it collapses back into the notch after ~¼ s.
- [ ] **Click-through (critical):** with the panel *closed*, click browser tabs, a Finder window's
      title bar and menu bar items right next to the notch. Every click must reach the app below.
      The invisible window is 648 × ~230 pt at the top centre, so test that whole area.
- [ ] Same with the panel *open*: clicks just outside the black shape reach the app below.
- [ ] Switch Spaces (Ctrl-←/→): the notch still works on every Space.
- [ ] Open a fullscreen app (green button): the panel is gone on that display. Leave fullscreen: it's back.
- [ ] Close the lid for 30 s, reopen, unlock: the panel still works.
- [ ] Record: which macOS version? `sw_vers`

**Unknowns to answer (these go into docs/ADR.md):**
- [ ] Does the panel stack correctly above the menu bar, and *below* Spotlight and notification
      banners? (Window level is `.statusBar`.)
- [ ] Do hover events arrive over the notch cutout itself? (If the panel never opens, this is why —
      report it; the fallback is a global mouse-moved monitor.)

## 2. Hover feel (5 min)

- [ ] Throw the pointer at the menu bar near the notch 20 times. Count how often the panel opens
      (target: 0).
- [ ] Deliberately move into the notch and slow down: it opens *before* the delay — that's the
      intent detection. Compare by turning off Settings → Hover → "Open when the pointer settles".
- [ ] Skim along the bottom edge of the notch: no flicker.
- [ ] Settings → Hover: change "Open after" to 600 ms; the change is felt immediately.
- [ ] Press Esc while open: it closes.

## 3. Performance — the product's whole claim (15 min, mostly waiting)

With media paused, clipboard history off and the notch collapsed:
```bash
Scripts/bench.sh 120          # or: curl -O the script and run it next to /Applications/Sill.app
```
- [ ] Sill average CPU ≤ 0.1% — value: ______
- [ ] Helper (perl) average CPU — value: ______
- [ ] RSS < 80 MB — value: ______
- [ ] Activity Monitor → Energy tab: Sill's "Energy Impact" — value: ______
- [ ] Repeat with music **playing**: CPU ______ / helper ______
- [ ] Repeat with **clipboard history on**: CPU ______ (this number goes next to the toggle)
- [ ] Open the panel: the footer's "cost receipt" (leaf icon) shows plausible numbers.

## 4. Displays (10 min, needs an external monitor)

- [ ] Settings → General → Show on "All displays": a black pill appears top-centre on the external
      monitor and opens on hover.
- [ ] Unplug and replug the monitor 5 times: always exactly one panel per display, none orphaned.
- [ ] Change the external display's resolution/scaling: the pill re-centres correctly.
- [ ] Lid closed with only the external display ("clamshell"), setting "Built-in display": the panel
      appears on the external display rather than nowhere.
- [ ] Fullscreen app on one display: the other display's panel still works.

## 5. Features (15 min)

**Now Playing**
- [ ] Play in Music, then Spotify, then YouTube in Safari: title/artist/artwork appear; the artwork
      colour glows softly into the black panel.
- [ ] Track change while collapsed: a short "peek" shows the new title, then it collapses.
- [ ] Play/pause/next/previous work. Drag the progress bar to seek.
- [ ] While playing and collapsed: artwork + a static waveform sit either side of the notch.
- [ ] Nothing playing: "No media detected", never a spinner.
- [ ] Log shows `Adapter stream started`. If it instead shows `falling back to notifications`,
      record the exit status lines — the adapter doesn't work on this macOS version.

**Shelf**
- [ ] Drag a file from Finder toward the notch: the notch **leans toward it** and opens into the
      shelf before you arrive. Drop it.
- [ ] Delete the original file: the shelf item still works (double-click opens it).
- [ ] Drag a photo out of Photos onto the notch (file promise path).
- [ ] Drag a shelf item out to the Desktop: it is **copied** (still on the shelf).
- [ ] Right-click: Open, Show in Finder, Share…, Pin, Remove all work. Pinned items survive "Clear".
- [ ] Drop a >1 GB file: "Copying…" tile appears; UI never freezes.
- [ ] Unknown: did the lean happen, or did the panel only open when the pointer reached the notch?
      (Tells us whether global drag monitors fire during Finder drags.)

**Clipboard** — ⚠ the macOS 15.4+ pasteboard privacy alert is the biggest unknown here.
- [ ] Clipboard tab → Turn on. Copy some text in another app.
- [ ] **Did macOS show an alert about Sill reading the pasteboard?** Yes / No — exact wording: ______
- [ ] The text appears; type to search; ↑/↓ then Enter copies it and closes the panel; ⌘V pastes.
- [ ] Copy a password in 1Password / Passwords: **no** entry appears.
- [ ] Copy an image and a file from Finder: both appear.
- [ ] Typing in the search field works, and after closing the panel your keystrokes go back to the
      app you were in (none are swallowed).

**Battery**
- [ ] Plug in / unplug the charger: a short peek with a bolt and the percentage.
- [ ] Battery tab: percentage, time remaining, health % and cycle count (compare with
      System Information → Power).

## 6. Settings

- [ ] Launch at login toggle: turn on, reboot (or log out/in), Sill starts. If it says "needs you to
      allow this", the button opens Login Items.
- [ ] Turn each module off in Settings → Modules: its tab disappears immediately.
- [ ] Pause Sill from the menu bar: every panel disappears; Resume brings them back.

---

## Report back

Paste into a GitHub issue (or send the files):
1. The ticked checklist with the values filled in.
2. `sw_vers` and the Mac model (e.g. MacBook Pro 14" M3).
3. The last 10 minutes of logs:
   ```bash
   log show --predicate 'subsystem == "app.sill.Sill"' --last 10m --info --debug > sill-log.txt
   ```
4. A 10-second screen recording of the expand animation (⇧⌘5) — useful for tuning and marketing.
