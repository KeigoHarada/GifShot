import AppKit
import Foundation
import ScreenCaptureKit
import SwiftUI

final class AppModel: ObservableObject {
  enum RecordingState {
    case idle
    case selecting
    case recording
    case encoding
    case completed(URL?)
    case failed(String)
  }

  @Published var recordingState: RecordingState = .idle

  private var hotkeyManager: HotkeyManager?
  private var overlayController: OverlayWindowController?
  private let recorder = Recorder()

  private var selectedRect: CGRect?

  init() {
    hotkeyManager = HotkeyManager(onPressed: { [weak self] in
      DispatchQueue.main.async {
        self?.toggleRecording()
      }
    })
    _ = hotkeyManager?.register()
  }

  deinit {
    hotkeyManager?.unregister()
    hideOverlay()
    recorder.stop()
  }

  var isRecording: Bool {
    if case .recording = recordingState { return true }
    return false
  }

  func toggleRecording() {
    switch recordingState {
    case .idle, .completed, .failed:
      startSelection()
    case .selecting:
      recordingState = .idle
      hideOverlay()
    case .recording:
      recorder.stop()
      recordingState = .encoding
      // 後続でエンコード処理へ
      recordingState = .idle
    case .encoding:
      break
    }
  }

  private func startSelection() {
    guard let screen = NSScreen.main else {
      recordingState = .failed("画面情報の取得に失敗しました")
      return
    }
    showOverlay(on: screen)
    recordingState = .selecting
  }

  private func showOverlay(on screen: NSScreen) {
    let frame = screen.frame
    let view = SelectionOverlayView(
      screenFrame: frame,
      onComplete: { [weak self] rect in
        guard let self = self else { return }
        self.selectedRect = rect
        self.hideOverlay()
        Task { @MainActor in
          await self.startRecording(on: screen)
        }
      },
      onCancel: { [weak self] in
        self?.hideOverlay()
        self?.recordingState = .idle
      }
    )
    let content = AnyView(view)
    overlayController = OverlayWindowController(content: content, screen: screen)
    overlayController?.showWindow(nil)
    if let window = overlayController?.window {
      window.orderFrontRegardless()
      window.makeKeyAndOrderFront(nil)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  private func hideOverlay() {
    overlayController?.close()
    overlayController = nil
  }

  @MainActor
  private func startRecording(on screen: NSScreen) async {
    do {
      let displays = try await SCShareableContent.current.displays

      // NSScreen → CGDirectDisplayID を取得
      let key = NSDeviceDescriptionKey("NSScreenNumber")
      let screenNumber = (screen.deviceDescription[key] as? NSNumber)?.uint32Value
      let screenID = screenNumber.map { CGDirectDisplayID($0) }

      let targetDisplay =
        (screenID != nil)
        ? displays.first(where: { $0.displayID == screenID! })
        : nil

      guard let display = targetDisplay ?? displays.first else {
        recordingState = .failed("ディスプレイの取得に失敗しました")
        return
      }

      let config = Recorder.Configuration(
        display: display, selectedRectInScreenSpace: selectedRect, framesPerSecond: 15)
      try await recorder.start(configuration: config) { [weak self] _ in
        // フレーム受領。後続でバッファリングしてGIF化する
      }
      recordingState = .recording
    } catch {
      recordingState = .failed("録画開始に失敗しました: \(error.localizedDescription)")
    }
  }

  func quitApp() {
    NSApp.terminate(nil)
  }
}
