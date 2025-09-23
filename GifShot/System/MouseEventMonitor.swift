import AppKit

final class MouseEventMonitor {
  private var downToken: Any?
  private var dragToken: Any?
  private var upToken: Any?

  func start(
    onDown: @escaping (NSPoint) -> Void,
    onDrag: @escaping (NSPoint) -> Void,
    onUp: @escaping (NSPoint) -> Void
  ) {
    stop()
    downToken = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { e in
      onDown(e.locationInWindow)
    }
    dragToken = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { e in
      onDrag(e.locationInWindow)
    }
    upToken = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { e in
      onUp(e.locationInWindow)
    }
  }

  func stop() {
    if let t = downToken {
      NSEvent.removeMonitor(t)
      downToken = nil
    }
    if let t = dragToken {
      NSEvent.removeMonitor(t)
      dragToken = nil
    }
    if let t = upToken {
      NSEvent.removeMonitor(t)
      upToken = nil
    }
  }

  deinit { stop() }
}
