import Foundation
import ImageIO
import UniformTypeIdentifiers

final class GifEncoder {
  private let frameDelay: Double
  private let loopCount: Int
  private var data = NSMutableData()
  private var dest: CGImageDestination?
  private var initialized = false
  private var gifProps: [CFString: Any] {
    return [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]]
  }
  private var frameProps: [CFString: Any] {
    return [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameDelay]]
  }

  init(frameDelay: Double, loopCount: Int = 0) {
    self.frameDelay = frameDelay
    self.loopCount = loopCount
  }

  func start(expectedFrameCount: Int = 0) {
    guard !initialized else { return }
    dest = CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, expectedFrameCount == 0 ? 1 : expectedFrameCount, nil)
    if let dest = dest {
      CGImageDestinationSetProperties(dest, gifProps as CFDictionary)
      initialized = true
    }
  }

  func addFrame(_ image: CGImage) {
    if !initialized { start() }
    guard let dest = dest else { return }
    CGImageDestinationAddImage(dest, image, frameProps as CFDictionary)
  }

  func finalizeData() -> Data? {
    guard let dest = dest else { return nil }
    if CGImageDestinationFinalize(dest) {
      return data as Data
    }
    return nil
  }
}
