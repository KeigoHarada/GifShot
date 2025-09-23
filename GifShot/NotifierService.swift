import Foundation
import UserNotifications
import AppKit

final class NotifierService: NSObject, UNUserNotificationCenterDelegate {
  private let categoryId = "gifshot.saved"
  private let openActionId = "gifshot.open"

  func requestAuthorization() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self

    // アクション付きカテゴリを登録
    let open = UNNotificationAction(identifier: openActionId, title: "保存先を開く", options: [])
    let category = UNNotificationCategory(identifier: categoryId, actions: [open], intentIdentifiers: [])
    center.setNotificationCategories([category])

    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error = error { Log.app.error("notification auth error: \(error.localizedDescription)") }
      Log.app.info("notification auth granted: \(granted)")
    }
  }

  func notifySaved(fileURL: URL) {
    let content = UNMutableNotificationContent()
    content.title = "スクリーンショットを保存しました"
    content.body = fileURL.lastPathComponent
    content.categoryIdentifier = categoryId
    content.userInfo = ["filePath": fileURL.path]

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        Log.app.error("notify add error: \(error.localizedDescription)")
      } else {
        Log.app.info("notify queued: \(fileURL.lastPathComponent)")
      }
    }
  }

  // フォアグラウンドでもバナー/サウンドを表示
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    return [.banner, .sound]
  }

  // クリック/アクションで保存先を開く
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    let userInfo = response.notification.request.content.userInfo
    guard let path = userInfo["filePath"] as? String else { return }
    let url = URL(fileURLWithPath: path)
    // デフォルトクリック/アクションとも同じハンドリング
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}
