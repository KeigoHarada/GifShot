import AppKit

final class ClipboardService {
  func copyPNG(image: NSImage) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { return }

    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setData(png, forType: .png)
  }
}
