# Owned

Tracks what you bought — return window, warranty, and eventually shipping — without you having to remember any of it yourself. See the full research and decision trail in the `claude/macless-app-ideas-2026-08-23.md` doc in the Macless/Citolex project for why this exists and what it's up against.

## Status: Phase 1 builds clean on a real macOS runner; TestFlight plumbing is in place, waiting on Apple Developer Portal setup

Everything in this repo was written in a Linux sandbox with no Xcode, no Swift compiler, and no Mac — same premise as Macless itself. `simulator-build.yml` is green (first real proof the `.iOSApplication` manifest is valid). `testflight.yml` is written and ready, mirroring the proven `ios-testflight.yml` pattern from the appledev (Citolex) repo, but it needs a one-time manual setup before it can actually reach TestFlight — see `TESTFLIGHT.md`. That setup is Apple Developer Portal / App Store Connect work that has to be done by a human with account access, not something any Claude session can do.

## Why a Swift Package instead of an .xcodeproj

Two real constraints shaped this, worth knowing before changing it:

1. **No `npm install` access in the sandbox this was built in.** The original plan was to scaffold this the same way Citolex is built — Capacitor, with native Swift plugins for the OS-level stuff. That's still a fine architecture in general, but `npm install` for any package (not just `@capacitor/*`, every package) returned a hard 403 from the sandbox's own network policy. There was no path to running `npx cap add ios` to generate a real Xcode project.
2. **A hand-written `.xcodeproj` is a worse bet than a hand-written `Package.swift` when nothing can be compiled to check it.** A `.pbxproj` file is hundreds of lines of UUID-linked plist with a lot of places to get subtly wrong with no way to catch it before CI. `Package.swift` with an `.iOSApplication` product is a much smaller surface — under 40 lines — so there's less for a mistake to hide in, and if the newer `.iOSApplication` API has a naming issue somewhere, that's a small, obvious diff once the build log shows it.

This also turned out to fit the product better anyway: Owned needs deep native access (PassKit, camera, local notifications, eventually on-device storage of parsed email data) with no meaningful web-UI layer, unlike Citolex which started life as a web reading experience. A plain native SwiftUI app is the more natural shape here, independent of the sandbox constraint that forced the decision.

If this turns out to be more trouble than it's worth once someone has real Xcode access, converting to a standard `.xcodeproj` is straightforward: open the package folder directly in Xcode, which can usually migrate it, or scaffold a fresh project and drag the `Sources/` folder in.

## What's actually built (Phase 1)

- A list of tracked purchases, sorted by whichever deadline is most urgent.
- Adding an item by hand: name, retailer, price, purchase date, a receipt photo (camera capture, no OCR yet), an optional return-window deadline (X days from purchase), an optional warranty deadline (a specific date).
- Local notifications 3 days before each deadline, with an "Add to Wallet" action right on the notification.
- The Wallet-add flow itself, using Apple's real `PKAddPassesViewController` — but the actual signed `.pkpass` generation is a clearly-marked stub (see `Services/WalletPassService.swift`). Generating a real pass needs a Pass Type ID certificate from the Apple Developer account, which is a credential that has to be created and added as a CI secret by a person, not something to hand to any Claude session. Wire the real signing step into `buildSignedPass(for:deadline:)` once that certificate exists — everything else in that file (the presentation flow, the one-tap confirmation) is already real.
- Everything stored locally in a flat JSON file in the app's own Documents directory. No account, no cloud sync, nothing sent anywhere — matching the same privacy stance as the rest of the Macless product line, and the actual reason Slice's data-brokering business model was explicitly ruled out for this product (see the app-ideas doc).

## What's deliberately not built yet (Phase 2)

The automatic email-based tracking — connect Gmail/Outlook, parse order/shipping/return/refund emails, log everything with zero manual entry — is the actual differentiator for this product (see the competitive research in the app-ideas doc for why nobody else does this end-to-end). It's planned as a paid tier, not built into Phase 1, for two reasons: it needs its own OAuth app review from Google (the sensitive Gmail-read scope goes through a slower, stricter approval process — worth starting early once there's a real product to submit for review, not left until the end), and it's real ongoing engineering work (retailers change their email templates over time) that deserves its own scoped effort rather than being bolted onto a first commit.

Also not built: receipt OCR (the camera capture just attaches a photo right now, doesn't read it), the automated claim-drafting email, and any UI to edit an existing item after it's been added.

## Project structure

```
Package.swift                  — the app manifest (see above for why this instead of .xcodeproj)
Sources/OwnedApp/
  OwnedApp.swift                — app entry point + notification-action handling
  Models/TrackedItem.swift      — the core data model
  Storage/ItemStore.swift       — local JSON persistence
  Storage/PhotoStorage.swift    — local receipt photo storage
  Services/NotificationService.swift  — local reminder scheduling
  Services/WalletPassService.swift    — Wallet add flow (signing stub, see above)
  Views/                        — SwiftUI screens
  Resources/Assets.xcassets/    — app icon (a placeholder, not final art) + accent color
.github/workflows/simulator-build.yml — CI: builds for iOS Simulator, no signing needed. Green.
.github/workflows/testflight.yml      — CI: builds, signs, archives, and uploads to TestFlight. Written and ready, needs the one-time setup in TESTFLIGHT.md before it can succeed.
TESTFLIGHT.md                  — the one-time manual Apple Developer Portal / App Store Connect setup testflight.yml depends on. Read this to actually get a build into TestFlight.
```

## Naming and domain

App name: **Owned**. Checked against the App Store and couldn't find an existing app using it, unlike five other candidates tried first (Backpocket collides with an active Levi's retail app, among others — full trail in the app-ideas doc). `getowned.app` looked unregistered as of this writing; worth confirming directly at registration time rather than trusting a DNS probe as final word. Bundle identifier is `dev.macless.owned` (set in `Package.swift`; the real Team ID is injected at CI build time from a GitHub secret rather than hardcoded — see `testflight.yml`).

## Next steps, roughly in order

1. ~~Get `simulator-build.yml` green on a real runner.~~ **Done.**
2. ~~Write the TestFlight build/sign/upload workflow.~~ **Done — see `testflight.yml` and `TESTFLIGHT.md`.**
3. **Do the one-time manual setup in `TESTFLIGHT.md`** (register the App ID, create one provisioning profile, register the app in App Store Connect, add 7 GitHub secrets — most reused directly from the existing Citolex setup). This is the actual next blocker, and it's Jackson's step, not something further automatable from this sandbox.
4. Add real app icon artwork (current one is a generated placeholder, not final design) — deprioritized per Jackson, not blocking TestFlight.
5. Once a build lands in TestFlight, add an internal testing group in App Store Connect and confirm the build actually installs and runs on a real device — that's the first true end-to-end validation.
6. Scope and start Phase 2 (email auto-import), starting with Amazon specifically given assumed order volume.
