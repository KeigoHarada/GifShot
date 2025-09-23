import AppKit

final class ClipboardService {
  func copyGIF(data: Data, fileURL: URL) {
    let pb = NSPasteboard.general
    pb.clearContents()
    // ファイルURLを書き込む（多くのアプリが受理）
    pb.writeObjects([fileURL as NSURL])
    // 生データのGIFも併記
    let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
    pb.setData(data, forType: gifType)
  }

  func copyGIF(data: Data) {
    let pb = NSPasteboard.general
    pb.clearContents()
    let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
    pb.setData(data, forType: gifType)
  }
}
