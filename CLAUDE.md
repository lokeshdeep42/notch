# CLAUDE.md — Working agreement for this repo

> Read this file completely before writing any code. Then read `docs/00-PRODUCT-SPEC.md`
> and `docs/01-ARCHITECTURE.md`. Do not start a milestone before reading its section in
> `docs/03-BUILD-PLAN.md`.

## What we are building

**Sill** (working name — see "Naming" below) is a macOS menu-bar utility that turns the
MacBook notch into an interactive hub: hover it and it expands into a panel with now-playing
controls, a drag-and-drop file shelf, and clipboard history. It collapses back to nothing.

**The entire product thesis is one sentence:** every competitor in this category either drains
your battery or breaks on external displays — this one does neither, provably.

That is not a marketing line. It is an engineering constraint that outranks every feature
request. See "Non-negotiables".

## Non-negotiables

These are hard constraints. If a task cannot be completed without violating one, stop and
say so rather than shipping a violation.

1. **Performance budget (the product's whole reason to exist)**
   - Idle CPU with the notch collapsed: **≤ 0.1%** averaged over 60s on Apple silicon.
   - Idle wakeups with the notch collapsed and no media playing: **as close to 0 as possible**.
   - Resident memory: **< 80 MB** steady state.
   - Activity Monitor "Energy Impact" must read as effectively zero when collapsed.
   - **No repeating timers may run while the notch is collapsed** unless explicitly listed in
     `docs/01-ARCHITECTURE.md` §Performance with a justification and a measured cost.
   - Every PR that adds a timer, a poll loop, or a global event monitor must state its measured
     cost in the commit message.

2. **No GPL/copyleft code.** This is a closed-source commercial product.
   - **Allowed to read and adapt:** MIT/BSD/Apache projects — `DynamicNotchKit` (MIT),
     `NotchDrop` (MIT), `Notchmeister` (BSD-3).
   - **Allowed to read for behaviour only, never copy a line:** `boring.notch` (GPL-3.0),
     `mew-notch` (GPLv3).
   - If you are unsure of a dependency's licence, do not add it. Ask.

3. **No feature may hard-depend on a private Apple framework without a fallback.** Now Playing
   uses a private-framework bridge (see `docs/02-TECHNICAL-REFERENCE.md` §Now Playing). It must
   degrade gracefully to a scripting-based fallback and then to "no media detected" — never to a
   crash, a spinner, or an empty panel with no explanation.

4. **Minimum permissions.** Do not request Accessibility, Screen Recording, or Input Monitoring
   unless a shipped feature genuinely needs it, and only at the moment the user first uses that
   feature. Trust is a selling point in this category. Screen Recording in particular is
   currently **out of scope** for v1.

5. **No App Store assumptions.** This ships outside the Mac App Store (Developer ID + notarised).
   Do not add sandbox entitlements or design around sandbox limitations.

6. **Multi-display correctness is a v1 feature, not a v2 polish item.** Every notch-related change
   must be validated against the display matrix in `docs/04-QA-CHECKLIST.md`.

## How to work in this repo

- **Work one milestone at a time**, in the order given in `docs/03-BUILD-PLAN.md`. Each task has
  explicit acceptance criteria. Do not move to the next task until the current one's criteria pass.
- **Milestone 0 is a spike.** Its purpose is to find out whether the hardest part works. If it
  does not, say so loudly instead of working around it.
- **Small, focused commits.** One task per commit. Conventional-commit style:
  `feat(notch): expand on hover with spring animation`.
- **Build and test before declaring a task done.** `Scripts/build.sh` and `Scripts/test.sh`.
- **Do not add third-party dependencies** without flagging it first, with the licence named.
  The approved list is in `docs/01-ARCHITECTURE.md` §Dependencies.
- **Record decisions.** When you make a non-obvious architectural choice, append a short entry to
  `docs/ADR.md` (date, decision, alternatives considered, why).
- **When Apple API behaviour is uncertain, write a tiny throwaway probe first** and confirm the
  behaviour on the actual OS version, rather than assuming. Several APIs here changed in
  macOS 15.4 and again in macOS 26; the reference doc flags which ones.
- **Flag anything in the docs that turns out to be wrong.** These specs were written from research,
  not from a working build. If reality disagrees with the spec, reality wins — update the doc in
  the same commit and note it.

## Code conventions

- Swift 6 language mode where practical; `@MainActor` on all UI-touching types.
- SwiftUI for views; AppKit for windows, tracking, drag sources, and anything SwiftUI cannot reach.
- No force unwraps outside tests. No `try!`. No `fatalError` in shipping paths.
- All user-facing strings through `String(localized:)` from day one (cheap now, expensive later).
- Logging via `os.Logger` with a per-subsystem category. No `print` in committed code.
- Feature modules must not import each other. They talk through `NotchCore` and `Services`.
- Prefer event-driven over polling everywhere. If you write a `Timer`, justify it.

## Definition of done (per task)

- [ ] Builds clean, zero warnings introduced.
- [ ] Unit tests for any non-trivial logic.
- [ ] Manually verified against the task's acceptance criteria.
- [ ] Performance budget re-checked if the task touches the run loop, timers, or observers.
- [ ] No new permission prompts introduced without a doc update.
- [ ] Committed with a message that says what and why.

## Key files

| Path | What it is |
|---|---|
| `docs/00-PRODUCT-SPEC.md` | What we're building and why; v1 scope and explicit non-goals |
| `docs/01-ARCHITECTURE.md` | Module layout, state machine, performance architecture |
| `docs/02-TECHNICAL-REFERENCE.md` | API-level details, gotchas, exact framework behaviour |
| `docs/03-BUILD-PLAN.md` | Milestones and tasks with acceptance criteria |
| `docs/04-QA-CHECKLIST.md` | The test matrix every release must pass |
| `docs/05-RELEASE.md` | Signing, notarisation, updates, licensing, launch |
| `docs/ADR.md` | Decision log (append-only) |

## Naming

"Sill" is a placeholder used throughout these docs and in the bundle identifier
(`app.sill.Sill`). **Before any public release**, the name must be trademark-checked and the
domain secured. Two hard rules regardless of the final name:

- **Never use "Dynamic Island"** in the product name, marketing copy, or feature names — it is an
  Apple trademark. Describe it generically ("notch hub", "the panel").
- Avoid "Notch-" prefixed names; that space is saturated (NotchNook, NotchDrop, NotchBay,
  NotchNest, NotchShelf, Notchy...).

When the name changes, it should be a single find-and-replace: keep the string in one place
(`Sources/Services/Branding.swift`) and reference it everywhere else.
