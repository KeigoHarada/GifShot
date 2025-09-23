import SwiftUI

final class OverlayHostingView<Content: View>: NSHostingView<Content> {
  override var acceptsFirstResponder: Bool { true }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.makeFirstResponder(self)
  }
  override func hitTest(_ point: NSPoint) -> NSView? {
    // 子ビューにイベントを流す
    return super.hitTest(point)
  }
}
