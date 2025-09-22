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
        window.isMovableByWindowBackground = false
        window.hasShadow = false
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.isReleasedWhenClosed = false

        self.hostingController = NSHostingController(rootView: content)
        window.contentView = hostingController?.view

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
