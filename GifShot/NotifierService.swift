import Foundation
import UserNotifications

final class NotifierService: NSObject, UNUserNotificationCenterDelegate {
  func requestAuthorization() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error = error {
        Log.app.error("notification auth error: \(error.localizedDescription)")
      }
      Log.app.info("notification auth granted: \(granted)")
    }
  }

  func notifySaved(fileURL: URL) {
    let content = UNMutableNotificationContent()
    content.title = "スクリーンショットを保存しました"
    content.body = fileURL.lastPathComponent

    let request = UNNotificationRequest(
      identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        Log.app.error("notify add error: \(error.localizedDescription)")
      } else {
        Log.app.info("notify queued: \(fileURL.lastPathComponent)")
      }
    }
  }

  // フォアグラウンドでもバナー/サウンドを表示
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    return [.banner, .sound]
  }
}
