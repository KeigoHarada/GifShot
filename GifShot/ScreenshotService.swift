import AppKit
import CoreImage
import CoreMedia
import Foundation
import ScreenCaptureKit

final class ScreenshotService: NSObject {
  struct Result {
    let image: NSImage
    let cgImage: CGImage
  }

  private let ciContext = CIContext(options: nil)

  func capture(rectInScreenSpace: CGRect, on screen: NSScreen) async throws -> Result {
    let displays = try await SCShareableContent.current.displays

    let key = NSDeviceDescriptionKey("NSScreenNumber")
    let screenNumber = (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    let screenID = screenNumber.map { CGDirectDisplayID($0) }

    guard
      let display =
        ((screenID != nil) ? displays.first(where: { $0.displayID == screenID! }) : displays.first)
    else {
      throw NSError(
        domain: "ScreenshotService", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "ディスプレイが見つかりません"])
    }

    let filter = SCContentFilter(display: display, excludingWindows: [])

    let config = SCStreamConfiguration()
    config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
    config.showsCursor = false
    config.capturesAudio = false
    config.queueDepth = 1

    let receiver = SingleFrameReceiver(
      ciContext: ciContext, rectInScreenSpace: rectInScreenSpace, screen: screen)
    let stream = SCStream(filter: filter, configuration: config, delegate: receiver)
    try stream.addStreamOutput(receiver, type: .screen, sampleHandlerQueue: receiver.queue)

    defer {
      Task {
        try? await stream.stopCapture()
        try? stream.removeStreamOutput(receiver, type: .screen)
      }
    }

    try await stream.startCapture()
    Log.overlay.info("screenshot capture started")

    let cgImage = try await receiver.firstFrameCropped()
    let nsImage = NSImage(
      cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    return Result(image: nsImage, cgImage: cgImage)
  }
}

private final class SingleFrameReceiver: NSObject, SCStreamOutput, SCStreamDelegate {
  let queue = DispatchQueue(label: "gifshot.screenshot.queue")
  private let ciContext: CIContext
  private let rectInScreenSpace: CGRect
  private let screen: NSScreen

  private var continuation: CheckedContinuation<CGImage, Error>?

  init(ciContext: CIContext, rectInScreenSpace: CGRect, screen: NSScreen) {
    self.ciContext = ciContext
    self.rectInScreenSpace = rectInScreenSpace
    self.screen = screen
  }

  func firstFrameCropped() async throws -> CGImage {
    return try await withCheckedThrowingContinuation { cont in
      continuation = cont
    }
  }

  func stream(
    _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    of outputType: SCStreamOutputType
  ) {
    guard outputType == .screen, let pixelBuffer = sampleBuffer.imageBuffer else { return }
    let ciImage = CIImage(cvImageBuffer: pixelBuffer)

    // 画面ポイント座標 → ピクセル座標へ変換
    let imageWidth = ciImage.extent.width
    let imageHeight = ciImage.extent.height
    let scaleX = imageWidth / screen.frame.width
    let scaleY = imageHeight / screen.frame.height

    let x = (rectInScreenSpace.minX - screen.frame.minX) * scaleX
    let y = (rectInScreenSpace.minY - screen.frame.minY) * scaleY
    let w = rectInScreenSpace.width * scaleX
    let h = rectInScreenSpace.height * scaleY

    let cropRect = CGRect(x: x, y: y, width: w, height: h)
    let cropped = ciImage.cropped(to: cropRect)
    guard let cgImage = ciContext.createCGImage(cropped, from: cropped.extent) else { return }

    if let cont = continuation {
      continuation = nil
      cont.resume(returning: cgImage)
    }
  }
}
