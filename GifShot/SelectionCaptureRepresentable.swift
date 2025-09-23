import SwiftUI

struct SelectionCaptureRepresentable: NSViewRepresentable {
  let screenFrame: CGRect
  let onComplete: (CGRect) -> Void
  let onCancel: () -> Void

  func makeNSView(context: Context) -> SelectionCaptureView {
    let v = SelectionCaptureView(screenFrame: screenFrame, onComplete: onComplete, onCancel: onCancel)
    return v
  }

  func updateNSView(_ nsView: SelectionCaptureView, context: Context) {}
}

final class SelectionCaptureView: NSView {
  private let screenFrame: CGRect
  private let onComplete: (CGRect) -> Void
  private let onCancel: () -> Void

  private var dragStartInView: NSPoint?
  private var dragCurrentInView: NSPoint?

  init(screenFrame: CGRect, onComplete: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
    self.screenFrame = screenFrame
    self.onComplete = onComplete
    self.onCancel = onCancel
    super.init(frame: .zero)
    wantsLayer = true
    postsFrameChangedNotifications = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override var acceptsFirstResponder: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let win = window {
      frame = win.contentView?.bounds ?? .zero
      autoresizingMask = [.width, .height]
      win.makeFirstResponder(self)
    }
  }

  override func hitTest(_ point: NSPoint) -> NSView? { self }

  override func mouseDown(with event: NSEvent) {
    let p = convert(event.locationInWindow, from: nil)
    dragStartInView = p
    dragCurrentInView = p
    Log.overlay.info("mouseDown at: \(NSStringFromPoint(p))")
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    let p = convert(event.locationInWindow, from: nil)
    dragCurrentInView = p
    needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    finishSelection()
  }

  func beginGlobal(at global: NSPoint) {
    let p = convertGlobalToView(global)
    dragStartInView = p
    dragCurrentInView = p
    needsDisplay = true
  }

  func updateGlobal(to global: NSPoint) {
    let p = convertGlobalToView(global)
    dragCurrentInView = p
    needsDisplay = true
  }

  func endGlobal(at _: NSPoint) {
    finishSelection()
  }

  private func convertGlobalToView(_ global: NSPoint) -> NSPoint {
    let windowPoint = window?.convertPoint(fromScreen: global) ?? global
    let p = convert(windowPoint, from: nil)
    return p
  }

  private func finishSelection() {
    let start = dragStartInView
    let end = dragCurrentInView
    dragStartInView = nil
    dragCurrentInView = nil
    needsDisplay = true

    guard let s = start, let e = end else {
      onCancel()
      return
    }
    let rectInView = NSRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(s.x - e.x), height: abs(s.y - e.y))
    if rectInView.width < 2 || rectInView.height < 2 {
      Log.overlay.info("mouseUp too small, cancel")
      onCancel()
      return
    }
    let rectInScreen = convertRectToScreen(rectInView)
    Log.overlay.info("mouseUp rect: \(NSStringFromRect(rectInScreen))")
    onComplete(rectInScreen)
  }

  private func convertRectToScreen(_ rect: NSRect) -> NSRect {
    let originInWindow = convert(rect.origin, to: nil)
    let windowRect = NSRect(origin: originInWindow, size: rect.size)
    return window?.convertToScreen(windowRect) ?? windowRect
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    ctx.setFillColor(NSColor.black.withAlphaComponent(0.2).cgColor)
    ctx.fill(bounds)

    if let s = dragStartInView, let e = dragCurrentInView {
      let x = min(s.x, e.x)
      let y = min(s.y, e.y)
      let w = abs(s.x - e.x)
      let h = abs(s.y - e.y)
      let rect = CGRect(x: x, y: y, width: w, height: h)

      ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.2).cgColor)
      ctx.fill(rect)
      ctx.setStrokeColor(NSColor.systemBlue.cgColor)
      ctx.setLineWidth(2)
      ctx.stroke(rect)
    }
  }
}
