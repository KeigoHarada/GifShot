import AppKit
import Foundation

final class SaveService {
  private let bookmarkKey = "saveFolderBookmark"

  func ensureDirectory() throws -> URL {
    if let bookmarked = resolveBookmarkedURL() {
      return bookmarked
    }

    // ユーザーのホーム直下のDocuments/GifShot
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let dir = documents.appendingPathComponent("GifShot", isDirectory: true)

    do {
      if !FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      }
      return dir
    } catch {
      if let picked = pickDirectory(initial: documents) {
        storeBookmark(url: picked)
        return picked
      }
      throw error
    }
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

  func saveGIF(data: Data) throws -> URL {
    let dir = try ensureDirectory()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let name = "GifShot_\(formatter.string(from: Date())).gif"
    let url = dir.appendingPathComponent(name)
    try data.write(to: url)
    return url
  }

  // MARK: - Security-scoped bookmarks
  private func resolveBookmarkedURL() -> URL? {
    guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
    var stale = false
    do {
      let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], bookmarkDataIsStale: &stale)
      if url.startAccessingSecurityScopedResource() {
        return url
      }
    } catch {}
    return nil
  }

  private func storeBookmark(url: URL) {
    if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
      UserDefaults.standard.set(data, forKey: bookmarkKey)
    }
  }

  private func pickDirectory(initial: URL) -> URL? {
    var pickedURL: URL?
    DispatchQueue.main.sync {
      let panel = NSOpenPanel()
      panel.prompt = "選択"
      panel.message = "保存先フォルダを選択してください"
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      panel.canCreateDirectories = true
      panel.directoryURL = initial
      if panel.runModal() == .OK, let url = panel.url {
        pickedURL = url
      }
    }
    return pickedURL
  }
}
