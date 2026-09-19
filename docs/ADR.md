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
- [ ] `ungive/mediaremote-adapter`: its licence, and whether bundling it is permitted
- [ ] macOS 15.4+ pasteboard privacy alert: does poll-then-read trigger it, and what the clipboard
      design became as a result
- [ ] Hardened runtime and the Perl subprocess: which entitlements, if any, were needed
- [ ] MediaRemote command/write support on macOS 26.x: available or hide the transport controls
- [ ] Clipboard store: plain JSON vs GRDB
- [ ] Whether `DynamicNotchKit` stayed as a dependency or was replaced with owned code
- [ ] Final product name and the trademark check behind it

---

## Entries
