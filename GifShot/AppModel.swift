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
  private let screenshotService = ScreenshotService()
  private let saveService = SaveService()
  private let clipboardService = ClipboardService()

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
          do {
            let result = try await self.screenshotService.capture(rectInScreenSpace: rect, on: screen)
            let url = try self.saveService.savePNG(image: result.image)
            self.clipboardService.copyPNG(image: result.image)
            self.recordingState = .completed(url)
            Log.app.info("screenshot saved: \(url.path)")
          } catch {
            self.recordingState = .failed("スクリーンショットに失敗: \(error.localizedDescription)")
            Log.app.error("screenshot failed: \(error.localizedDescription)")
          }
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
    // いまはスクショモード優先のため未使用
    do {
      let _ = try await SCShareableContent.current.displays
    } catch {}
  }

  func quitApp() {
    NSApp.terminate(nil)
  }
}
