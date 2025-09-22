import AppKit
import SwiftUI

final class OverlayWindowController: NSWindowController {
    private var hostingController: NSHostingController<AnyView>?

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
        window.level = .screenSaver
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

        let hosting = NSHostingController(rootView: content)
        self.hostingController = hosting

        super.init(window: window)

        if let contentView = window.contentView {
            let view = hosting.view
            view.translatesAutoresizingMaskIntoConstraints = true
            view.frame = contentView.bounds
            view.autoresizingMask = [.width, .height]
            contentView.addSubview(view)
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hosting.view)
        Log.overlay.info("OverlayWindow key=\(window.isKeyWindow) firstResponder=\(String(describing: window.firstResponder))")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
