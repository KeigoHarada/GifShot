import Foundation
import AppKit
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
        case .recording, .encoding:
            recordingState = .idle
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
                self.hideOverlay()
                self.recordingState = .recording
                // 後続で選択領域rectを録画へ引き渡す
            },
            onCancel: { [weak self] in
                self?.hideOverlay()
                self?.recordingState = .idle
            }
        )
        let content = AnyView(view)
        overlayController = OverlayWindowController(content: content, screen: screen)
        overlayController?.showWindow(nil)
        overlayController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideOverlay() {
        overlayController?.close()
        overlayController = nil
    }

    func quitApp() {
        NSApp.terminate(nil)
    }
}
