import CoreImage
import CoreMedia
import Foundation
import ScreenCaptureKit

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
    streamConfig.minimumFrameInterval = CMTime(
      value: 1, timescale: CMTimeScale(configuration.framesPerSecond))
    streamConfig.showsCursor = true
    streamConfig.capturesAudio = false
    streamConfig.queueDepth = 8

    Log.recorder.info(
      "start capture fps=\(configuration.framesPerSecond) displayID=\(configuration.display.displayID)"
    )
    let stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
    try stream.addStreamOutput(
      self, type: SCStreamOutputType.screen, sampleHandlerQueue: sampleQueue)
    try await stream.startCapture()
    self.stream = stream
  }

  func stop() {
    if let stream = stream {
      Task { [weak self] in
        Log.recorder.info("stop capture")
        try? await stream.stopCapture()
        guard let strongSelf = self else { return }
        try? stream.removeStreamOutput(strongSelf, type: SCStreamOutputType.screen)
        strongSelf.stream = nil
      }
    }
    onFrame = nil
  }
}

extension Recorder: SCStreamOutput {
  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == SCStreamOutputType.screen,
      let pixelBuffer = sampleBuffer.imageBuffer
    else { return }
    let ciImage = CIImage(cvImageBuffer: pixelBuffer)
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
    Log.recorder.debug("frame")
    onFrame?(cgImage)
  }
}

extension Recorder: SCStreamDelegate {}
