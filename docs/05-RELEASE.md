# 05 — Release, Distribution, and Launch

## Distribution model

**Direct distribution, outside the Mac App Store.** Not negotiable: the Now Playing bridge uses a
private framework, and the shelf needs arbitrary file access. Both are incompatible with the
sandbox. Plan accordingly — do not add sandbox entitlements.

Consequences:
- Developer ID signing + hardened runtime + notarisation are mandatory. The free/unsigned route
  (which boring.notch takes) produces a Gatekeeper wall that costs installs and looks unserious.
- You control pricing, trials, and update cadence entirely. Slow Setapp/App Store update cycles are
  a named competitor complaint; direct distribution is the fix.

Requires an **Apple Developer Program membership ($99/year)**. Notarisation itself is free.

## Signing and notarisation

```bash
# 1. Sign inner components first (helper tools, frameworks), then the app bundle
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <NAME> (<TEAMID>)" \
  "Sill.app/Contents/Frameworks/MediaRemoteAdapter.framework"

codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <NAME> (<TEAMID>)" \
  --entitlements Sill.entitlements \
  "Sill.app"

# 2. Verify
codesign --verify --deep --strict --verbose=2 Sill.app

# 3. Notarise
ditto -c -k --keepParent Sill.app Sill.zip
xcrun notarytool submit Sill.zip --keychain-profile "AC_PASSWORD" --wait

# 4. Staple and verify as a clean machine would
xcrun stapler staple Sill.app
spctl -a -vvv Sill.app
```

Gotchas:
- **Sign inner-out.** The bundled adapter framework and any helper script's executable must be
  signed before the outer bundle, or notarisation fails with unhelpful errors.
- The Perl-based adapter runs `/usr/bin/perl` as a subprocess. Confirm the hardened runtime does
  not block it; if it does, you may need specific entitlements — **verify early**, not on release
  day. Record the outcome in `docs/ADR.md`.
- Test the final DMG on a **clean machine or a fresh VM**, not your dev machine, which trusts
  everything.

## Auto-updates

**Sparkle 2.x** (MIT), via SPM.
- EdDSA-signed appcast; keep the private key out of the repo and out of CI logs.
- Host `appcast.xml` on your own domain.
- Support delta updates once the app is large enough to matter.
- Never auto-install without consent; offer "check automatically" on by default with an obvious off.
- Ship a real changelog in the update dialog. In a category where "slow updates" is a complaint,
  visible, frequent, well-described updates are a competitive asset.

## Payments and licensing

### Hard rule: do not use raw Stripe as your only processor

The category has a cautionary tale. NotchNook took roughly $100K in its first week (~7,700 sales)
and Stripe moved to close the account without notice and refund everything within five days; it
was only restored after press coverage. A one-person shop cannot absorb that.

Use a **merchant of record**, which also handles global VAT/sales tax for you:

| Option | Fees | Notes |
|---|---|---|
| **Polar** | ~4% + $0.40 | Best developer experience, open source, current indie favourite |
| **Lemon Squeezy** | ~5% + $0.50 | Fast approval, built-in licence keys; acquired by Stripe in 2024 and roadmap has reportedly slowed |
| **Paddle** | ~5% + fixed | Strongest once past roughly $10K MRR |

Keep a **second processor configured but idle** so a freeze is a config change, not an outage.

### Licensing implementation
- Licence keys issued by the MoR (or Keygen if you want it decoupled).
- Activation stores a signed token locally; validate the signature offline.
- **Offline grace period** of at least 14 days — people use laptops on planes.
- Device limit: 3–5 seats, with self-service deactivation.
- Never let a failed network check brick a paid app. Fail open, then nag.

### Pricing
- Intro **$15–19**, standard **$24** one-time. Paid major-version upgrades later.
- **7-day full trial.** NotchNook launched at $40 with a 1-hour trial and had to reverse both.
- Consider free-forever media + battery, with shelf/clipboard/hover-tuning as the paid unlock.
- Honour refunds quickly and visibly. "Hard to get a refund" appears in competitor reviews and is
  entirely self-inflicted.

## Setapp (later, not at launch)

Terms per Setapp's developer documentation: single-app developers receive **85%** of app
subscription revenue and **75%** of app purchase revenue. Under the Membership model Setapp
distributes **70%** across developers proportional to usage, plus a **+20% partner fee** for users
you refer (up to 90% total). Payouts are monthly with a **2–2.5 month ramp** for new apps and up to
28 days of stats lag.

Treat it as **discovery, not income**. MacPaw cites roughly 30k unique impressions in an app's
first days on the platform, which is real, but per-app payouts are usage-proportional and modest.
Apply only once the app is stable and well-reviewed — a buggy Setapp debut burns a channel you
cannot easily re-enter.

Note: Setapp *Mobile* (iOS, EU) shut down in February 2026; desktop Setapp is unaffected.

## Launch playbook

What actually drives installs for indie Mac utilities, in rough order of value:

1. **r/macapps.** The centre of gravity for this category. Read and follow the self-promotion
   rules before posting. Lead with what it does and what it costs, be present in the comments, and
   act on feedback publicly — lo.cafe visibly changed NotchNook's price and trial length after
   Reddit pushback, and got credit for it.
2. **Product Hunt.** Tuesday–Thursday. Alcove, NotchNook and MediaMate all launched there. Line up
   your first ten supporters in advance.
3. **A landing page whose hero is the proof, not a feature list.** Your differentiator is
   measurable: show the Activity Monitor screenshot. Show a 10-second clip of the expand animation
   and a clip of plugging in a monitor and nothing breaking.
4. **Build in public on X.** The Tony Dinh model — ship visibly, post numbers, answer everyone.
   Start before launch, not after.
5. **Editorial pitches:** MacStories, 9to5Mac, MacRumors, Cult of Mac. MacStories in particular
   covers menu-bar and notch utilities. A short, specific pitch beats a press release.
6. **Homebrew cask.** `brew install --cask <name>` earns goodwill and removes install friction.
7. **YouTube reviewers** who cover Mac utilities — send a free licence, no strings.

Positioning copy should speak to people who already tried and abandoned a competitor. Something in
the register of: *"You tried a notch app. It ate your battery or broke when you plugged in a
monitor. This one doesn't — here's the proof."*

## Revenue expectations (calibration, not a promise)

Public numbers from comparable indie Mac utilities, mostly self-reported:

| App | Reported |
|---|---|
| NotchNook | ~$100K in launch week (~7,700 sales) — an outlier spike, not a run rate |
| Lunar | ~$7K/month, the closest realistic steady-state comparable |
| DevUtils | ~$5K MRR |
| Xnapper | ~$4–6K MRR; **sold for $150,000 in 2024** |
| MacWhisper | ~$100K total revenue as of its 2023 snapshot |

Read this as: a strong launch can produce a five-figure spike; a well-maintained utility can settle
into low-to-mid four figures monthly. Treat anything above that as upside, and note that these are
self-reported figures, not audited.

## Legal and naming

- **"Dynamic Island" is an Apple trademark.** Never use it in the name, the marketing, or a feature
  label. Say "notch hub" or "the panel".
- Trademark-check the final name in your target markets before spending on branding.
- Avoid "Notch-" prefixes — NotchNook, NotchDrop, NotchBay, NotchNest, NotchShelf and Notchy are all
  taken, and the space is confusing for users and bad for search.
- Ship a real privacy policy. Since you are claiming privacy as a differentiator, it must be
  accurate and specific: what is stored, where, and what never leaves the machine.
- Include the licences of any bundled third-party components in an About → Acknowledgements panel.
