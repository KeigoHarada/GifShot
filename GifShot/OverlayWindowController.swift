import AppKit
import SwiftUI

final class OverlayWindowController: NSWindowController {
  private var hostingView: OverlayHostingView<AnyView>?

  init(nsView contentView: NSView, screen: NSScreen) {
    let frame = screen.frame
    let style: NSWindow.StyleMask = [.borderless]
    let window = OverlayWindow(
      contentRect: frame,
      styleMask: style,
      backing: .buffered,
      defer: false,
      screen: screen
    )
    window.level = .modalPanel
    window.isOpaque = false
    window.backgroundColor = .clear
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.ignoresMouseEvents = false
    window.acceptsMouseMovedEvents = true
    window.isMovableByWindowBackground = false
    window.hasShadow = false
    window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
    window.isReleasedWhenClosed = false
    window.hidesOnDeactivate = false

    super.init(window: window)

    let container = NSView(frame: window.contentView?.bounds ?? NSRect(origin: .zero, size: frame.size))
    container.autoresizingMask = [.width, .height]
    window.contentView = container

    contentView.translatesAutoresizingMaskIntoConstraints = true
    contentView.frame = container.bounds
    contentView.autoresizingMask = [.width, .height]
    container.addSubview(contentView)

    NSApp.activate(ignoringOtherApps: true)
    window.orderFrontRegardless()
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(contentView)
    Log.overlay.info("OverlayWindow key=\(window.isKeyWindow) firstResponder=\(String(describing: window.firstResponder)) contentBounds=\(NSStringFromRect(container.bounds)) subviewFrame=\(NSStringFromRect(contentView.frame))")
  }

  init(content: AnyView, screen: NSScreen) {
    let frame = screen.frame
    let style: NSWindow.StyleMask = [.borderless]
    let window = OverlayWindow(
      contentRect: frame,
      styleMask: style,
      backing: .buffered,
      defer: false,
      screen: screen
    )
    window.level = .modalPanel
    window.isOpaque = false
    window.backgroundColor = .clear
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.ignoresMouseEvents = false
    window.acceptsMouseMovedEvents = true
    window.isMovableByWindowBackground = false
    window.hasShadow = false
    window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
    window.isReleasedWhenClosed = false
    window.hidesOnDeactivate = false

    super.init(window: window)

    let container = NSView(frame: window.contentView?.bounds ?? NSRect(origin: .zero, size: frame.size))
    container.autoresizingMask = [.width, .height]
    window.contentView = container

    let hv = OverlayHostingView(rootView: content)
    hv.translatesAutoresizingMaskIntoConstraints = true
    hv.frame = container.bounds
    hv.autoresizingMask = [.width, .height]
    container.addSubview(hv)
    self.hostingView = hv

    NSApp.activate(ignoringOtherApps: true)
    window.orderFrontRegardless()
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(hv)
    Log.overlay.info("OverlayWindow key=\(window.isKeyWindow) firstResponder=\(String(describing: window.firstResponder)) containerBounds=\(NSStringFromRect(container.bounds)) hvFrame=\(NSStringFromRect(hv.frame))")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}
