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
///    Type ID certificate, which is a different credential from the app's
///    own code-signing cert. Bundling that private key inside the app
///    binary would mean anyone who extracts the IPA gets a key that can
///    forge passes claiming to be from Owned — so signing happens
///    server-side instead, in a small standalone Cloudflare Worker
///    (jackson26-source/owned-pass-signer) that Jackson deployed and holds
///    the private key as a Worker secret, never bundled here. This file
///    just POSTs the pass details to that endpoint and gets back a signed
///    `.pkpass` — no key material ever touches the client. See that repo's
///    DEPLOY.md for how the signing endpoint itself is set up and rotated.
@MainActor
final class WalletPassService: NSObject {
  static let shared = WalletPassService()

  /// The owned-pass-signer Worker's signing endpoint. Stateless — every
  /// request is signed and forgotten, nothing about a pass is stored
  /// there. See jackson26-source/owned-pass-signer.
  private static let signingEndpoint = URL(string: "https://owned-pass-signer.localinfine.workers.dev/api/sign-pass")!

  private override init() {
    super.init()
  }

  /// Presents Apple's own "Add to Wallet" confirmation screen for a
  /// given item/deadline. Call this from wherever the person tapped
  /// "Add to Wallet" — either the notification action or a button in
  /// the item detail screen.
  func presentAddPass(for item: TrackedItem, deadline: TrackedDeadline, from presentingViewController: UIViewController) async {
    guard let passData = await buildSignedPass(for: item, deadline: deadline) else {
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

  /// Asks the owned-pass-signer Worker to build and sign a real .pkpass
  /// for this item/deadline, and returns the raw bytes on success.
  ///
  /// Returns nil on any failure (network error, non-200 response, or a
  /// malformed body) — the caller shows a plain "couldn't add this right
  /// now" alert rather than crashing. A failure here means the signing
  /// request didn't succeed, not that Wallet support is unconfigured;
  /// worth checking the Worker's own /health endpoint if this starts
  /// failing consistently.
  private func buildSignedPass(for item: TrackedItem, deadline: TrackedDeadline) async -> Data? {
    var request = URLRequest(url: Self.signingEndpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let deadlineKind: String
    switch deadline.kind {
    case .returnWindow: deadlineKind = "return"
    case .warranty: deadlineKind = "warranty"
    }

    let isoFormatter = ISO8601DateFormatter()
    let requestBody: [String: Any] = [
      "itemName": item.name,
      "retailer": item.retailer,
      "deadlineKind": deadlineKind,
      "dueDateISO": isoFormatter.string(from: deadline.date),
      // The signer doesn't need this to be globally unique in any strong
      // sense — it just needs to be stable per deadline so re-adding the
      // same deadline's pass later would produce the same serial number.
      "serialNumber": deadline.id.uuidString,
      "notes": item.notes,
    ]

    guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
      print("WalletPassService: failed to encode request body")
      return nil
    }
    request.httpBody = httpBody

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        print("WalletPassService: signing request returned no HTTP response")
        return nil
      }
      guard httpResponse.statusCode == 200 else {
        let detail = String(data: data, encoding: .utf8) ?? "<no body>"
        print("WalletPassService: signing endpoint returned \(httpResponse.statusCode) — \(detail)")
        return nil
      }
      return data
    } catch {
      print("WalletPassService: signing request failed — \(error)")
      return nil
    }
  }

  private func presentUnavailableAlert(from presentingViewController: UIViewController) {
    let alert = UIAlertController(
      title: "Couldn't add to Wallet",
      message: "Something went wrong creating this Wallet pass. Check your connection and try again in a moment.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    presentingViewController.present(alert, animated: true)
  }
}
