# Getting Owned onto TestFlight

This is the one-time manual setup `testflight.yml` depends on. Owned is a
plain SwiftPM `.iOSApplication` package with one target — no share
extension, no App Group — so this is simpler than the equivalent setup for
Citolex (`appledev/SIGNING.md`), and several pieces can be reused directly
from that existing setup instead of generated fresh, since they're tied to
your Apple Developer account, not to any one app.

## What you can reuse from the Citolex (appledev) setup

These are account-level, not app-level — the same values work for any app
under your Apple Developer team:

- Your **Distribution certificate** (`.p12` + its password) — Apple limits
  how many active Distribution certs an account can have, so reusing the
  existing one is the correct move, not a shortcut.
- Your **App Store Connect API key** (Key ID, Issuer ID, `.p8` file) — also
  account-level.
- Your **Team ID**.

If you still have the original files from setting up Citolex, you don't
need to regenerate any of the three above — just copy those same secret
*values* into this repo's own GitHub secrets (GitHub doesn't share secrets
between repos automatically, even under one account, so each repo needs its
own copy of the same value).

If you no longer have those files handy, `appledev/SIGNING.md` steps 1-3
and 8-9 explain how to generate/find them again from scratch.

## What's new and specific to Owned

### 1. Register the App ID

Go to [Identifiers](https://developer.apple.com/account/resources/identifiers/list) →
**+** → App IDs → App → register `dev.macless.owned`. No special
capabilities need to be checked — Owned's camera use and local notifications
don't require anything beyond the Info.plist usage strings already in the
app, and presenting the "Add to Wallet" sheet (`PKAddPassesViewController`)
doesn't require an App ID capability either (that's separate from the Pass
Type ID certificate the Wallet *pass-generation* stub is blocked on — see
the repo's README).

### 2. Create one App Store distribution provisioning profile

Go to [Profiles](https://developer.apple.com/account/resources/profiles/list) →
**+** → App Store distribution → select `dev.macless.owned` → select your
(reused) Distribution certificate → name it exactly **Owned App Store**
(the workflow file's `ExportOptions.plist` references this exact name).
Download the `.mobileprovision` file.

Base64-encode it the same way as the Citolex setup:

```
openssl base64 -in owned_app_store.mobileprovision -out owned_profile_base64.txt
```

(or `certutil -encode` on Windows, stripping the BEGIN/END lines it adds)

### 3. Register the app in App Store Connect

Go to [App Store Connect](https://appstoreconnect.apple.com) → My Apps → **+** →
New App. Platform iOS, name "Owned", bundle ID `dev.macless.owned` (pick it
from the dropdown — it'll be there from step 1), any SKU. This creates the
app record the upload step needs to find. You can leave every other field
(screenshots, description, pricing) blank for now — none of that is needed
for a build to land in TestFlight, only for it to eventually go out for
public/external review.

### 4. Add the secrets to this repo

Go to this repo's **Settings → Secrets and variables → Actions → New
repository secret** and add each of these:

| Secret name | Value | New or reused? |
|---|---|---|
| `APPLE_TEAM_ID` | Your Team ID | Reused |
| `IOS_DIST_CERT_P12_BASE64` | base64 of your Distribution cert `.p12` | Reused |
| `IOS_DIST_CERT_PASSWORD` | The password on that `.p12` | Reused |
| `APPSTORE_API_KEY_ID` | Your App Store Connect API Key ID | Reused |
| `APPSTORE_API_ISSUER_ID` | Your App Store Connect API Issuer ID | Reused |
| `APPSTORE_API_PRIVATE_KEY_BASE64` | base64 of your API key's `.p8` file | Reused |
| `IOS_APP_PROVISION_PROFILE_BASE64` | base64 of the **Owned App Store** profile from step 2 | **New** |

Only the last one is new. Everything else is a straight copy of a value you
already have from setting up Citolex.

### 5. Push (or just re-run the workflow)

Once all seven secrets are in place, either push any commit to `main`, or
go to the **Actions** tab → **Build and upload Owned to TestFlight** →
**Run workflow**. This builds, code-signs, archives, exports an `.ipa`, and
uploads it to App Store Connect automatically. It'll show up in TestFlight
processing within a few minutes of a successful upload.

## If a build fails

Open the failed run in the **Actions** tab and read the step that went
red — the "Validate signing setup" step in particular is designed to fail
loudly with a specific reason (wrong Team ID, wrong bundle ID, bad base64)
rather than let you hit a cryptic `xcodebuild` error further down. Almost
everything at this stage is a signing mismatch — a name, bundle ID, or
secret that doesn't line up exactly — not a real code problem. Paste the
error back and it can be diagnosed from there, same as the simulator-build
fix earlier in this project.

## After the first successful upload

TestFlight builds still need at least an internal testing group set up in
App Store Connect (Jackson adds himself as a tester) before the build is
actually installable on a device — that's a few clicks in App Store
Connect's TestFlight tab, not something this workflow can do for you.
External testing (sharing with anyone outside your own team) additionally
requires Apple's "Beta App Review," a separate, lighter-weight review than
full App Store review, but still Apple's own manual step with its own
turnaround time.
