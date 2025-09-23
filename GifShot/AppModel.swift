import AppKit
import Foundation
import ScreenCaptureKit
import SwiftUI

final class AppModel: ObservableObject {
  enum RecordingState: Equatable {
    case idle
    case selecting
    case recording
    case encoding
    case completed(URL?)
    case failed(String)
  }

  @Published var recordingState: RecordingState = .idle
  @Published var maxDurationSeconds: Int

  private var hotkeyManager: HotkeyManager?
  private let recorder = Recorder()
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
  private var currentScreenFrame: CGRect?
  private var currentDisplayID: CGDirectDisplayID?
  private var capturedFrames: [CGImage] = []
  private let targetFps: Int = 15
  private var autoStopTask: Task<Void, Never>?

  private let maxDurationKey = "maxDurationSeconds"

  init() {
    let stored = UserDefaults.standard.integer(forKey: maxDurationKey)
    let initial = stored == 0 ? 60 : stored
    self.maxDurationSeconds = min(max(1, initial), 300)

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
    autoStopTask?.cancel()
  }

  var isRecording: Bool {
    if case .recording = recordingState { return true }
    return false
  }

  func updateMaxDuration(seconds: Int) {
    let clamped = min(max(1, seconds), 300)
    maxDurationSeconds = clamped
    UserDefaults.standard.set(clamped, forKey: maxDurationKey)
  }

  func quitApp() {
    NSApp.terminate(nil)
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
      autoStopTask?.cancel()
      autoStopTask = nil
      recorder.stop()
      recordingState = .encoding
      encodeAndFinish()
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
          self.currentScreenFrame = frame
          let key = NSDeviceDescriptionKey("NSScreenNumber")
          let screenNumber = (screen.deviceDescription[key] as? NSNumber)?.uint32Value
          self.currentDisplayID = screenNumber.map { CGDirectDisplayID($0) }

          Log.overlay.info(
            "Selection completed rect=\(NSStringFromRect(rect)) on screen=\(NSStringFromRect(frame))"
          )
          self.mouseMonitor.stop()
          self.hideOverlays()
          Task { @MainActor in
            await self.startRecordingStream()
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
        window.ignoresMouseEvents = false
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
  private func startRecordingStream() async {
    guard let displayID = currentDisplayID, currentScreenFrame != nil else {
      recordingState = .failed("ディスプレイ情報が不正です")
      return
    }
    do {
      let displays = try await SCShareableContent.current.displays
      guard let display = displays.first(where: { $0.displayID == displayID }) ?? displays.first
      else {
        recordingState = .failed("ディスプレイの取得に失敗しました")
        return
      }
      capturedFrames.removeAll(keepingCapacity: true)
      let config = Recorder.Configuration(
        display: display, selectedRectInScreenSpace: nil, framesPerSecond: targetFps)
      try await recorder.start(configuration: config) { [weak self] cgImage in
        guard let self = self, let selection = self.selectedRect,
          let screenFrame = self.currentScreenFrame
        else { return }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let scaleX = width / screenFrame.width
        let scaleY = height / screenFrame.height
        let w = max(1, round(selection.width * scaleX))
        let h = max(1, round(selection.height * scaleY))
        let x = max(0, round((selection.minX - screenFrame.minX) * scaleX))
        let yFromBottom = (selection.minY - screenFrame.minY) * scaleY
        let y = max(0, round(height - yFromBottom - h))
        let cropRect = CGRect(
          x: min(x, width - 1), y: min(y, height - 1), width: min(w, width), height: min(h, height))
        if let cropped = cgImage.cropping(to: cropRect) {
          self.capturedFrames.append(cropped)
        }
      }
      recordingState = .recording
      Log.recorder.info("recording started")

      autoStopTask?.cancel()
      let duration = maxDurationSeconds
      autoStopTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000_000)
        await MainActor.run {
          guard let self = self, self.recordingState == .recording else { return }
          Log.recorder.info("auto stop after \(duration)s")
          self.toggleRecording()
        }
      }
    } catch {
      recordingState = .failed("録画開始に失敗しました: \(error.localizedDescription)")
      Log.recorder.error("failed to start: \(error.localizedDescription)")
    }
  }

  private func encodeAndFinish() {
    guard !capturedFrames.isEmpty else {
      recordingState = .failed("フレームがありません")
      return
    }
    let frameDelay = 1.0 / Double(targetFps)
    let encoder = GifEncoder(frameDelay: frameDelay)
    encoder.start(expectedFrameCount: capturedFrames.count)
    for frame in capturedFrames { encoder.addFrame(frame) }
    guard let data = encoder.finalizeData() else {
      recordingState = .failed("GIF生成に失敗")
      return
    }
    do {
      let url = try saveService.saveGIF(data: data)
      clipboardService.copyGIF(data: data, fileURL: url)
      notifier.notifySaved(fileURL: url)
      recordingState = .completed(url)
      Log.app.info("gif saved: \(url.path)")
    } catch {
      recordingState = .failed("保存に失敗: \(error.localizedDescription)")
    }
    capturedFrames.removeAll(keepingCapacity: false)
  }
}
