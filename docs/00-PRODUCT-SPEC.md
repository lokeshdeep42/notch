# 00 — Product Spec

## The problem

The MacBook notch is dead space. A dozen apps try to make it useful. Almost all of them are
disliked for the same handful of reasons, repeated across Reddit, GitHub issues, Setapp reviews
and forums:

| Recurring complaint | Who it hits |
|---|---|
| Battery / idle CPU drain | NotchNook (users report 3–5%/hr idle; dev advised rolling back a version), boring.notch (open issue: "5% an hour idle") |
| Media stops being detected | Everyone, after macOS 15.4 locked down the private MediaRemote framework |
| Breaks on external displays | NotchNook, several others — "doesn't work on connected display" |
| Permission prompts that never stop | "it constantly asks to allow permissions — which I have" |
| Expands when you're just reaching for the menu bar | Category-wide |
| Gets in the way in fullscreen | DynamicLake, others |
| Updates lag (especially on Setapp) | NotchNook |
| Widgets too big for the space | boring.notch issue #1037 |

Meanwhile the free open-source option (boring.notch) is unsigned, so installing it means walking
past Gatekeeper, and it carries a long backlog of exactly these bugs.

**So the market is proven but the execution bar is low.** NotchNook took roughly $100K in its
first week (~7,700 sales) despite these problems. The opportunity is not more features. It is
the same features, done properly.

## The wedge

> **The notch app that disappears.**

One sentence users should be able to repeat: *"It's the one that doesn't eat your battery and
doesn't fall apart when you plug in a monitor."*

Everything else — the shelf, the clipboard, the media controls — is table stakes we must match.
The wedge is that we can put a number on our idle cost and publish it, and that our multi-display
behaviour is boring and correct.

This is a defensible wedge for three reasons:
1. It is measurable, so it can be proven in a screenshot on the landing page.
2. It is the thing competitors are *structurally* bad at — most poll on a timer for everything.
3. It is hard to retrofit. Fixing it in a shipped app means rewriting the core.

## Target user

A MacBook Pro / Air owner on macOS 14+ who:
- keeps a lot of apps in the menu bar and cares about battery life,
- frequently docks to one or two external displays,
- moves files between apps and windows often (the shelf),
- already tried one notch app and uninstalled it.

That last group is the primary acquisition target. Marketing copy should speak directly to
people who bounced off a competitor.

## v1 scope (ship this, nothing more)

1. **The notch panel itself.** Hover to expand, leave to collapse. Correct on notched and
   non-notched Macs, on built-in and external displays, across Spaces, with fullscreen apps,
   through sleep/wake and display reconfiguration.
2. **Tunable hover behaviour.** Adjustable enter-delay and exit-delay, and a dead-zone so
   reaching for the menu bar does not trigger expansion. This directly fixes a category-wide
   complaint and is cheap to build.
3. **Now Playing.** Track, artist, artwork, scrubber, play/pause/next/prev. Works post-15.4 via
   the adapter bridge, with a scripting fallback for Music and Spotify, and an honest
   "no media detected" state.
4. **File shelf.** Drag files in, drag them back out as real files, pin items so they survive
   "clear", multi-select, quick reveal in Finder, share sheet.
5. **Clipboard history.** Text, images, files. Searchable. Ignores password-manager copies.
   Configurable retention. Off by default until the user enables it (permission-hygiene point).
6. **Battery and charging status** in the collapsed pill — event-driven, zero polling.
7. **Settings + onboarding.** Explains each permission at the moment it is needed, deep-links to
   the exact System Settings pane, and verifies the grant.
8. **Licensing.** Real 7-day trial, one-time purchase, Sparkle auto-updates.

## Explicit non-goals for v1

Listed so they do not creep in. These are v1.x / v2 candidates, ranked by how often users ask
for them:

- System monitor (CPU / RAM / disk / network graphs)
- Pomodoro / focus timer with app and site blocking
- Meeting and microphone live activities
- Screenshot capture, OCR, colour picker, GIF recording
- Weather, calendar, notes, scratchpad
- Trackpad gestures
- Lock-screen presence
- Custom widget SDK / plugins
- HUD replacement for volume and brightness
- Windows version

## Why someone pays for this

Against **free boring.notch**: we are signed and notarised (no Gatekeeper dance), we do not drain
the battery, we do not break on external displays, and we ship fixes quickly.

Against **NotchNook / DynamicLake / Alcove**: we do the three features people actually use, we
publish our idle cost, our multi-display behaviour works, and our hover doesn't misfire. Alcove
is the quality benchmark for animation feel — we have to be at least as good there, because it is
the one thing that category's happiest users talk about.

## Pricing and business model

- **One-time licence, ~$15–19 intro / $24 standard.** Paid major-version upgrades later.
  Subscription resentment is loud and specific in this category's reviews.
- **7-day full-feature trial** (changed from 14 days on 2026-09-23, see ADR). NotchNook launched
  with a 1-hour trial and a $40 price and had to walk both back after Reddit feedback. A week is
  still a real trial — don't repeat that.
- **Free tier consideration:** media + battery free forever; shelf + clipboard + hover tuning are
  the paid unlock. This maximises install base and word-of-mouth, which is how utilities in this
  category actually spread.
- **Do not use raw Stripe as the only processor.** NotchNook's ~$100K was frozen by Stripe with
  five days' notice to refund everything; it was only restored after press coverage. Use a
  merchant-of-record: Polar, Lemon Squeezy, or Paddle. Details in `docs/05-RELEASE.md`.
- **Setapp is a later, supplementary channel** — real discovery, modest usage-proportional
  payouts, and a 2–2.5 month revenue ramp. Not a launch strategy.

## Success criteria

| Horizon | Signal |
|---|---|
| End of weekend | Notch panel survives the full display/sleep/fullscreen matrix at ≤0.1% idle CPU, with Now Playing rendering |
| Week 2 | 5 external testers confirm no accidental triggering, no battery complaints, no display bugs |
| Launch week | Landing page can honestly show an Activity Monitor screenshot as the headline proof |
| Month 3 | Conversion rate and refund rate known; decide on Setapp |

## The one thing to get right

If the panel feels even slightly sticky, laggy, or unpredictable on hover, nothing else matters.
Users in this category describe the good apps purely in terms of feel. Budget real time for the
animation and the hover state machine.
