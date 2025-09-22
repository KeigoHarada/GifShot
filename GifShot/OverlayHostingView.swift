import SwiftUI

final class OverlayHostingView<Content: View>: NSHostingView<Content> {
  override var acceptsFirstResponder: Bool { true }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.makeFirstResponder(self)
  }
  override func hitTest(_ point: NSPoint) -> NSView? {
    // 透明領域でも自身でイベントを受ける
    return self
  }
}
