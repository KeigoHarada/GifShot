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

    var isRecording: Bool {
        if case .recording = recordingState { return true }
        return false
    }

    func toggleRecording() {
        switch recordingState {
        case .idle, .completed, .failed:
            recordingState = .recording
        case .selecting, .recording, .encoding:
            recordingState = .idle
        }
    }

    func quitApp() {
        NSApp.terminate(nil)
    }
}
