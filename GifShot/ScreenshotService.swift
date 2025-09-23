import Foundation
import AppKit
import CoreGraphics

final class ScreenshotService {
  struct Result {
    let image: NSImage
    let cgImage: CGImage
  }

  func capture(rectInScreenSpace: CGRect, on screen: NSScreen) -> Result? {
    let cgRect = convertToQuartzGlobal(rect: rectInScreenSpace, screen: screen)

    guard let cgImage = CGWindowListCreateImage(
      cgRect,
      .optionOnScreenOnly,
      kCGNullWindowID,
      [.bestResolution, .boundsIgnoreFraming]
    ) else {
      return nil
    }
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    return Result(image: nsImage, cgImage: cgImage)
  }

  private func convertToQuartzGlobal(rect: CGRect, screen: NSScreen) -> CGRect {
    // AppKitは原点が左下、Quartz Globalは一般に左上基準。対象スクリーン領域内で反転する
    let screenFrame = screen.frame
    let x = rect.origin.x
    let y = screenFrame.maxY - rect.maxY
    return CGRect(x: x, y: y, width: rect.width, height: rect.height)
  }
}
