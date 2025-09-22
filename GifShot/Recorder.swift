import Foundation
import ScreenCaptureKit
import CoreImage
import CoreMedia

final class Recorder: NSObject {
    struct Configuration {
        let display: SCDisplay
        let selectedRectInScreenSpace: CGRect?
        let framesPerSecond: Int
    }

    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "gifshot.recorder.queue")
    private let ciContext = CIContext(options: nil)

    private var onFrame: ((CGImage) -> Void)?

    func start(configuration: Configuration, onFrame: @escaping (CGImage) -> Void) async throws {
        stop()
        self.onFrame = onFrame

        let filter = SCContentFilter(display: configuration.display, excludingWindows: [])

        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.framesPerSecond))
        streamConfig.showsCursor = true
        streamConfig.capturesAudio = false
        streamConfig.queueDepth = 8
        // 初期は全画面キャプチャ。矩形切り出しは後段のエンコードで適用予定

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        if let stream = stream {
            Task { [weak self] in
                try? await stream.stopCapture()
                try? stream.removeStreamOutput(self)
                self?.stream = nil
            }
        }
        onFrame = nil
    }
}

extension Recorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        onFrame?(cgImage)
    }
}
