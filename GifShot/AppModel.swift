import AppKit
import Foundation
import SwiftUI
import ScreenCaptureKit

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
        Log.hotkey.info("Toggle recording by hotkey")
        self?.toggleRecording()
      }
    })
    let ok = hotkeyManager?.register() ?? false
    Log.hotkey.info("Register hotkey result: \(ok)")
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
    Log.app.info("toggleRecording from state=\(String(describing: self.recordingState))")
    switch recordingState {
    case .idle, .completed, .failed:
      startSelection()
    case .selecting:
      recordingState = .idle
      hideOverlay()
    case .recording:
      Log.recorder.info("Stop recording requested")
      recorder.stop()
      recordingState = .encoding
      recordingState = .idle
    case .encoding:
      break
    }
  }

  private func screenAtMouse() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    for screen in NSScreen.screens {
      if screen.frame.contains(mouse) { return screen }
    }
    return NSScreen.main
  }

  private func startSelection() {
    guard let screen = screenAtMouse() else {
      recordingState = .failed("画面情報の取得に失敗しました")
      return
    }
    Log.overlay.info("Start selection on screen frame=\(NSStringFromRect(screen.frame))")
    showOverlay(on: screen)
    recordingState = .selecting
  }

  private func showOverlay(on screen: NSScreen) {
    let frame = screen.frame
    let nsView = SelectionCaptureView(
      screenFrame: frame,
      onComplete: { [weak self] rect in
        guard let self = self else { return }
        self.selectedRect = rect
        Log.overlay.info("Selection completed rect=\(NSStringFromRect(rect))")
        self.hideOverlay()
        Task { @MainActor in
          await self.startRecording(on: screen)
        }
      },
      onCancel: { [weak self] in
        Log.overlay.info("Selection canceled")
        self?.hideOverlay()
        self?.recordingState = .idle
      }
    )
    overlayController = OverlayWindowController(nsView: nsView, screen: screen)
    overlayController?.showWindow(nil)
    if let window = overlayController?.window {
      window.orderFrontRegardless()
      window.makeKeyAndOrderFront(nil)
      Log.overlay.info("Overlay window shown and key: \(window.isKeyWindow)")
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  private func hideOverlay() {
    if let win = overlayController?.window {
      Log.overlay.info("Hide overlay. wasKey=\(win.isKeyWindow)")
    }
    overlayController?.close()
    overlayController = nil
  }

  @MainActor
  private func startRecording(on screen: NSScreen) async {
    do {
      let displays = try await SCShareableContent.current.displays

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
        Log.recorder.debug("frame received")
        // 後続でバッファリングしてGIF化する
      }
      recordingState = .recording
      Log.recorder.info("recording started")
    } catch {
      recordingState = .failed("録画開始に失敗しました: \(error.localizedDescription)")
      Log.recorder.error("failed to start: \(error.localizedDescription)")
    }
  }

  func quitApp() {
    NSApp.terminate(nil)
  }
}
