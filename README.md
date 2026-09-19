# Sill — spec pack

A macOS menu-bar utility that turns the MacBook notch into an interactive hub: now-playing
controls, a drag-and-drop file shelf, and clipboard history — that costs essentially nothing when
idle and does not break on external displays.

## How to use this pack

Drop these files at the root of a new git repo:

```
your-repo/
├── CLAUDE.md
├── README.md
└── docs/
    ├── 00-PRODUCT-SPEC.md
    ├── 01-ARCHITECTURE.md
    ├── 02-TECHNICAL-REFERENCE.md
    ├── 03-BUILD-PLAN.md
    ├── 04-QA-CHECKLIST.md
    ├── 05-RELEASE.md
    └── ADR.md
```

Then open Claude Code in that directory. It reads `CLAUDE.md` automatically.

## Kickoff prompt

Paste this as your first message to Claude Code:

> Read CLAUDE.md, then docs/00-PRODUCT-SPEC.md, docs/01-ARCHITECTURE.md and
> docs/02-TECHNICAL-REFERENCE.md. Then read Milestone 0 in docs/03-BUILD-PLAN.md.
>
> Before writing code, tell me: (1) your understanding of the product thesis in one sentence,
> (2) anything in the specs you think is wrong, risky, or underspecified, and (3) your plan for
> M0-T1 through M0-T8.
>
> Do not start coding until I confirm. Then work through Milestone 0 one task at a time, stopping
> after each for me to verify the acceptance criteria on real hardware.

## Read this before you start

- **Milestone 0 is the whole weekend's real value.** It answers whether the hard part —
  a borderless panel over the notch that survives Spaces, fullscreen, sleep/wake and display
  changes at near-zero idle cost — is achievable. Everything else is ordinary app work.
- **The specs are research-derived, not build-verified.** Items marked **⚠ VERIFY** in
  `docs/02-TECHNICAL-REFERENCE.md` need a five-line probe on real hardware before you build on
  them. When reality disagrees with the doc, update the doc in the same commit.
- **Licences matter here.** `boring.notch` and `mew-notch` are GPL. You can read them for
  behaviour; you cannot copy code into a paid closed-source app. `DynamicNotchKit`, `NotchDrop`
  and `Notchmeister` are MIT/BSD and safe.
- **"Sill" is a placeholder name.** Trademark-check before any public release, and never use
  "Dynamic Island" — it is Apple's mark.
