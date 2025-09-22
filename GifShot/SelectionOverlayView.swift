import SwiftUI

struct SelectionOverlayView: View {
    let screenFrame: CGRect
    let onComplete: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil

    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(start.x - current.x)
        let h = abs(start.y - current.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragStart == nil {
                                dragStart = value.startLocation
                                Log.overlay.info("drag start: \(NSStringFromPoint(NSPoint(x: value.startLocation.x, y: value.startLocation.y)))")
                            }
                            dragCurrent = value.location
                        }
                        .onEnded { _ in
                            if let rect = selectionRect, rect.width > 2, rect.height > 2 {
                                Log.overlay.info("drag end with rect: \(NSStringFromRect(NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)))")
                                onComplete(rect.offsetBy(dx: screenFrame.minX, dy: screenFrame.minY))
                            } else {
                                Log.overlay.info("drag cancelled (too small)")
                                onCancel()
                            }
                        }
                )

            if let rect = selectionRect {
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }

            HStack(spacing: 8) {
                Button("キャンセル") { onCancel() }
            }
            .padding(12)
        }
    }
}
