import Foundation
import UserNotifications

/// Schedules the local reminders that make this app worth opening.
///
/// Everything here is a *local* notification (UNUserNotificationCenter),
/// not a push notification — there's no server in Phase 1, so there's
/// nothing to push from. Local notifications don't need any special
/// Xcode capability or entitlement, just the runtime permission prompt.
@MainActor
final class NotificationService {
      static let shared = NotificationService()

      /// Custom action identifier for the "Add this to Wallet?" affordance
      /// that shows directly on the notification — this is the mechanic
      /// Jackson specifically wants: scan/log happens quietly, then a
      /// notification offers the one-tap Wallet add, rather than a fully
      /// silent add (which Apple's PassKit doesn't allow — see
      /// WalletPassService.swift for why).
      static let addToWalletActionID = "ADD_TO_WALLET"
      static let deadlineCategoryID = "DEADLINE_REMINDER"

      private init() {}

      func requestAuthorizationIfNeeded() async -> Bool {
                let center = UNUserNotificationCenter.current()
                let settings = await center.notificationSettings()

                switch settings.authorizationStatus {
                          case .authorized, .provisional:
                              return true
                          case .denied:
                              return false
                          case .notDetermined:
                              do {
                                                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
                              } catch {
                                                print("NotificationService: authorization request failed — \(error)")
                                                return false
                              }
                          @unknown default:
                              return false
                }
      }

      func registerNotificationCategories() {
                let addToWallet = UNNotificationAction(
                              identifier: Self.addToWalletActionID,
                              title: "Add to Wallet",
                              options: [.foreground]
                )
                let category = UNNotificationCategory(
                              identifier: Self.deadlineCategoryID,
                              actions: [addToWallet],
                              intentIdentifiers: [],
                              options: []
                )
                UNUserNotificationCenter.current().setNotificationCategories([category])
      }

      /// Schedules a reminder for a single deadline. Called once per
      /// deadline whenever an item is added or edited — existing requests
      /// for the same deadline are replaced, not stacked, so editing a date
      /// never leaves a stale duplicate reminder behind.
      func scheduleReminder(for item: TrackedItem, deadline: TrackedDeadline, daysBefore: Int = 3) {
                let center = UNUserNotificationCenter.current()
                let requestID = reminderIdentifier(itemID: item.id, deadlineID: deadline.id)
                center.removePendingNotificationRequests(withIdentifiers: [requestID])

                guard let fireDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: deadline.date),
                      fireDate > Date() else {
                                    return
                      }

                let content = UNMutableNotificationContent()
                content.title = titleForDeadline(deadline, itemName: item.name)
                content.body = bodyForDeadline(deadline, item: item, daysBefore: daysBefore)
                content.sound = .default
                content.categoryIdentifier = Self.deadlineCategoryID
                content.userInfo = [
                              "itemID": item.id.uuidString,
                              "deadlineID": deadline.id.uuidString
                ]

                var comps = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
                comps.hour = 9 // a reasonable default send time; not user-configurable yet
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
                center.add(request) { error in
                                                 if let error {
                                                                   print("NotificationService: failed to schedule reminder — \(error)")
                                                 }
                                    }
      }

      func cancelReminders(for item: TrackedItem) {
                let ids = item.deadlines.map { reminderIdentifier(itemID: item.id, deadlineID: $0.id) }
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
      }

      private func reminderIdentifier(itemID: UUID, deadlineID: UUID) -> String {
                "deadline-\(itemID.uuidString)-\(deadlineID.uuidString)"
      }

      private func titleForDeadline(_ deadline: TrackedDeadline, itemName: String) -> String {
                switch deadline.kind {
                          case .returnWindow: return "Return window closing — \(itemName)"
                          case .warranty: return "Warranty expiring — \(itemName)"
                }
      }

      private func bodyForDeadline(_ deadline: TrackedDeadline, item: TrackedItem, daysBefore: Int) -> String {
                let dayWord = daysBefore == 1 ? "day" : "days"
                switch deadline.kind {
                          case .returnWindow:
                              return "\(daysBefore) \(dayWord) left to return this from \(item.retailer)."
                          case .warranty:
                              return "\(daysBefore) \(dayWord) left on the warranty from \(item.retailer)."
                }
      }
}
