import Foundation
import UserNotifications

final class NotifierService {
  func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func notifySaved(fileURL: URL) {
    let content = UNMutableNotificationContent()
    content.title = "スクリーンショットを保存しました"
    content.body = fileURL.lastPathComponent

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }
}
