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
  private let recorder = Recorder()
  private let screenshotService = ScreenshotService()
  private let saveService = SaveService()
  private let clipboardService = ClipboardService()
  private let mouseMonitor = MouseEventMonitor()
  private let notifier = NotifierService()

  private struct OverlayItem {
    let screen: NSScreen
    let controller: OverlayWindowController
    let view: SelectionCaptureView
  }

  private var overlayItems: [OverlayItem] = []
  private var activeOverlayIndex: Int?

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
    hideOverlays()
    recorder.stop()
    mouseMonitor.stop()
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
      mouseMonitor.stop()
      hideOverlays()
    case .recording:
      Log.recorder.info("Stop recording requested")
      recorder.stop()
      recordingState = .encoding
      recordingState = .idle
    case .encoding:
      break
    }
  }

  private func startSelection() {
    Log.overlay.info("Start selection on all screens: count=\(NSScreen.screens.count)")
    showOverlaysOnAllScreens()
    recordingState = .selecting

    mouseMonitor.start(
      onDown: { [weak self] global in
        guard let self else { return }
        if self.activeOverlayIndex == nil {
          if let idx = self.overlayItems.firstIndex(where: { $0.screen.frame.contains(global) }) {
            self.activeOverlayIndex = idx
          }
        }
        if let idx = self.activeOverlayIndex {
          self.overlayItems[idx].view.beginGlobal(at: global)
        }
      },
      onDrag: { [weak self] global in
        guard let self, let idx = self.activeOverlayIndex else { return }
        self.overlayItems[idx].view.updateGlobal(to: global)
      },
      onUp: { [weak self] global in
        guard let self, let idx = self.activeOverlayIndex else { return }
        self.overlayItems[idx].view.endGlobal(at: global)
      }
    )
  }

  private func showOverlaysOnAllScreens() {
    hideOverlays()
    NSApp.activate(ignoringOtherApps: true)

    for screen in NSScreen.screens {
      let frame = screen.frame
      let view = SelectionCaptureView(
        screenFrame: frame,
        onComplete: { [weak self] rect in
          guard let self = self else { return }
          self.selectedRect = rect
          Log.overlay.info(
            "Selection completed rect=\(NSStringFromRect(rect)) on screen=\(NSStringFromRect(frame))"
          )
          self.mouseMonitor.stop()
          self.hideOverlays()

          // ここで screen の値を送らず、必要情報に分解して渡す
          let key = NSDeviceDescriptionKey("NSScreenNumber")
          let screenNumber = (screen.deviceDescription[key] as? NSNumber)?.uint32Value
          let displayID = screenNumber.map { CGDirectDisplayID($0) }

          Task { @MainActor in
            do {
              let result = try await self.screenshotService.capture(
                rectInScreenSpace: rect,
                displayID: displayID ?? 0,
                screenFrame: frame
              )
              let url = try self.saveService.savePNG(image: result.image)
              self.clipboardService.copyPNG(image: result.image)
              self.notifier.notifySaved(fileURL: url)
              self.recordingState = .completed(url)
              Log.app.info("screenshot saved: \(url.path)")
            } catch {
              self.recordingState = .failed("スクリーンショットに失敗: \(error.localizedDescription)")
              Log.app.error("screenshot failed: \(error.localizedDescription)")
            }
          }
        },
        onCancel: { [weak self] in
          Log.overlay.info("Selection canceled on screen=\(NSStringFromRect(frame))")
          self?.mouseMonitor.stop()
          self?.hideOverlays()
          self?.recordingState = .idle
        }
      )
      let controller = OverlayWindowController(nsView: view, screen: screen)
      controller.showWindow(nil)
      if let window = controller.window {
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        Log.overlay.info(
          "Overlay window shown and key: \(window.isKeyWindow) for screen=\(NSStringFromRect(frame))"
        )
      }
      let item = OverlayItem(screen: screen, controller: controller, view: view)
      overlayItems.append(item)
    }
  }

  private func hideOverlays() {
    for item in overlayItems {
      if let win = item.controller.window {
        Log.overlay.info(
          "Hide overlay. wasKey=\(win.isKeyWindow) for screen=\(NSStringFromRect(item.screen.frame))"
        )
      }
      item.controller.close()
    }
    overlayItems.removeAll()
    activeOverlayIndex = nil
  }

  @MainActor
  private func startRecording(on screen: NSScreen) async {
    do {
      let _ = try await SCShareableContent.current.displays
    } catch {}
  }

  func quitApp() {
    NSApp.terminate(nil)
  }
}
