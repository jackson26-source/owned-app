import Foundation
import PassKit
import UIKit

/// Handles the "add this deadline to Apple Wallet" flow.
///
/// Two things worth knowing before touching this file:
///
/// 1. There is no such thing as a silent, zero-tap Wallet add. PassKit's
///    `PKAddPassesViewController` always presents a confirmation screen
///    that the person has to tap through — this is Apple's own anti-spam
///    design, not a limitation of this app. So the real flow is: scan
///    happens quietly in the background (Phase 2), a notification asks
///    "Add this to Wallet?", and tapping it gets you to *this* screen for
///    one more tap. One tap total from the notification, not zero — that
///    actually is the ceiling on the platform.
///
/// 2. A real .pkpass file has to be cryptographically signed with a Pass
///    Type ID certificate from Jackson's own Apple Developer account
///    (a different credential from the app's own code-signing cert).
///    That's a real secret that needs to be generated in the Apple
///    Developer portal and added as a GitHub Actions secret by a human —
///    not something any Claude session should ever be handed or asked to
///    enter. Until that secret exists, `buildSignedPass(for:deadline:)`
///    below is a clearly-marked stub that returns nil instead of a real
///    pass. Wire in the real signing step there once the certificate
///    exists; everything else in this file (the presentation flow) is
///    already real and doesn't need to change.
@MainActor
final class WalletPassService: NSObject {
      static let shared = WalletPassService()

      private override init() {
                super.init()
      }

      /// Presents Apple's own "Add to Wallet" confirmation screen for a
      /// given item/deadline. Call this from wherever the person tapped
      /// "Add to Wallet" — either the notification action or a button in
      /// the item detail screen.
      func presentAddPass(for item: TrackedItem, deadline: TrackedDeadline, from presentingViewController: UIViewController) {
                guard let passData = buildSignedPass(for: item, deadline: deadline) else {
                              presentUnavailableAlert(from: presentingViewController)
                              return
                }

                do {
                              let pass = try PKPass(data: passData)
                              guard let addController = PKAddPassesViewController(pass: pass) else {
                                                presentUnavailableAlert(from: presentingViewController)
                                                return
                              }
                              presentingViewController.present(addController, animated: true)
                } catch {
                              print("WalletPassService: failed to construct PKPass — \(error)")
                              presentUnavailableAlert(from: presentingViewController)
                }
      }

      /// TODO(Phase 1 → real signing): build and sign an actual .pkpass
      /// bundle here once the Pass Type ID certificate exists. A .pkpass is
      /// a zip of a pass.json (the pass content — deadline name, item name,
      /// due date, relevant-date for a lock-screen surface) plus icon/logo
      /// images, a manifest.json of SHA-1 hashes, and a signature file
      /// produced with the Pass Type ID cert + Apple's WWDR intermediate
      /// certificate. That signing step almost certainly needs to happen
      /// server-side or in a CI step with the cert as a secret — it isn't
      /// something to do purely on-device with a bundled private key.
      ///
      /// Returns nil until that's wired up, which is what tells the caller
      /// above to show the "not set up yet" message instead of crashing.
      private func buildSignedPass(for item: TrackedItem, deadline: TrackedDeadline) -> Data? {
                return nil
      }

      private func presentUnavailableAlert(from presentingViewController: UIViewController) {
                let alert = UIAlertController(
                              title: "Wallet isn't set up yet",
                              message: "Adding this to Apple Wallet needs a one-time setup step that hasn't been done for this build yet.",
                              preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                presentingViewController.present(alert, animated: true)
      }
}
