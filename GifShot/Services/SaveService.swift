import AppKit
import Foundation

final class SaveService {
  func ensureDirectory() throws -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("GifShot", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  func savePNG(image: NSImage) throws -> URL {
    let dir = try ensureDirectory()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let name = "GifShot_\(formatter.string(from: Date())).png"
    let url = dir.appendingPathComponent(name)

    guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
    else {
      throw NSError(
        domain: "SaveService", code: -1, userInfo: [NSLocalizedDescriptionKey: "PNG変換に失敗"])
    }
    try png.write(to: url)
    return url
  }
}
