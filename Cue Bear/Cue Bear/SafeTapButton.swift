import SwiftUI

/// A button that filters out scrolls: only triggers if the finger didn't move much.
/// Adds a tiny delay (~50ms) to differentiate from scrolling.
struct SafeTapButton<Content: View>: View {
    var action: () -> Void
    var content: () -> Content

    @State private var isPressed = false
    @State private var moved = false

    var body: some View {
        content()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed { isPressed = true; moved = false }
                        let distance = hypot(value.translation.width, value.translation.height)
                        if distance > 12 { moved = true }
                    }
                    .onEnded { _ in
                        let shouldTap = isPressed && !moved
                        isPressed = false; moved = false
                        if shouldTap {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                action()
                            }
                        }
                    }
            )
    }
}

