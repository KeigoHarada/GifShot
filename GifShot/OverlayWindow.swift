import AppKit

final class OverlayWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown: Log.overlay.info("window event: leftMouseDown")
    case .leftMouseUp: Log.overlay.info("window event: leftMouseUp")
    case .leftMouseDragged: Log.overlay.debug("window event: leftMouseDragged")
    default: break
    }
    super.sendEvent(event)
  }
}
