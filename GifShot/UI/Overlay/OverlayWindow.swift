import AppKit

final class OverlayWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  private var dragLogSkip = 0

  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown: Log.overlay.info("window event: leftMouseDown")
    case .leftMouseUp: Log.overlay.info("window event: leftMouseUp")
    case .leftMouseDragged:
      dragLogSkip += 1
      if dragLogSkip % 30 == 0 { Log.overlay.debug("window event: leftMouseDragged (throttle)") }
    default: break
    }
    super.sendEvent(event)
  }
}
