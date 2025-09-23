import SwiftUI
import AppKit

struct HotkeyCaptureView: View {
  @Environment(  .dismiss) private var dismiss
  let onCaptured: (UInt32, UInt32) -> Void

  @State private var displayText: String = "ショートカットを押してください"

  var body: some View {
    VStack(spacing: 12) {
      Text(displayText)
      Button("キャンセル") { dismiss() }
    }
    .frame(width: 260)
    .padding(16)
    .background(Color(.windowBackgroundColor))
    .onAppear { displayText = "ショートカットを押してください" }
    .background(HotkeyCaptureRepresentable { keyCode, flags in
      let mods = HotkeyStore.carbonModifiers(from: flags)
      onCaptured(UInt32(keyCode), mods)
      dismiss()
    })
  }
}

private struct HotkeyCaptureRepresentable: NSViewRepresentable {
  let onKey: (UInt16, NSEvent.ModifierFlags) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    view.addTrackingRect(view.bounds, owner: context.coordinator, userData: nil, assumeInside: true)
    view.window?.makeFirstResponder(context.coordinator)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onKey: onKey) }

  final class Coordinator: NSView {
    private let onKey: (UInt16, NSEvent.ModifierFlags) -> Void
    init(onKey: @escaping (UInt16, NSEvent.ModifierFlags) -> Void) {
      self.onKey = onKey
      super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
      onKey(event.keyCode, event.modifierFlags)
    }
  }
}
