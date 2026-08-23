import SwiftUI
import UserNotifications

@main
struct OwnedApp: App {
      @StateObject private var itemStore = ItemStore()
      @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

      var body: some Scene {
                WindowGroup {
                              ContentView()
                                  .environmentObject(itemStore)
                                  .task {
                                                        NotificationService.shared.registerNotificationCategories()
                                                        appDelegate.itemStore = itemStore
                                  }
                }
      }
}

/// A thin AppDelegate is still needed even in a pure-SwiftUI app for one
/// reason: handling what happens when someone taps the "Add to Wallet"
/// action directly on a notification, which comes in through the
/// UNUserNotificationCenterDelegate callback rather than through SwiftUI's
/// own view lifecycle.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
      var itemStore: ItemStore?

      func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
                UNUserNotificationCenter.current().delegate = self
                return true
      }

      func userNotificationCenter(
                _ center: UNUserNotificationCenter,
                didReceive response: UNNotificationResponse,
                withCompletionHandler completionHandler: @escaping () -> Void
      ) {
                defer { completionHandler() }

                guard response.actionIdentifier == NotificationService.addToWalletActionID else { return }

                let userInfo = response.notification.request.content.userInfo
                guard
                    let itemIDString = userInfo["itemID"] as? String,
                    let deadlineIDString = userInfo["deadlineID"] as? String,
                    let itemID = UUID(uuidString: itemIDString),
                    let deadlineID = UUID(uuidString: deadlineIDString),
                    let itemStore,
                    let item = itemStore.items.first(where: { $0.id == itemID }),
                    let deadline = item.deadlines.first(where: { $0.id == deadlineID })
                else { return }

                Task { @MainActor in
                                  guard let root = UIApplication.shared.connectedScenes
                                      .compactMap({ $0 as? UIWindowScene })
                                      .first?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                                  else { return }
                                  WalletPassService.shared.presentAddPass(for: item, deadline: deadline, from: root)
                                  itemStore.markWalletPassAdded(itemID: item.id, deadlineID: deadline.id)
                     }
      }
}
