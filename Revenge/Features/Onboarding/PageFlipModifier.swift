import SwiftUI

// MARK: - PageFlipModifier

/// Applies a 3D page-turn rotation around the leading (left) edge.
///
/// - `progress` = 0   → page is flat and fully visible.
/// - `progress` = 1   → page has rotated 180° (fully flipped away).
/// - Opacity snaps to 0 once the page passes its midpoint (progress > 0.5).
/// - A drop-shadow that fades as the page lifts simulates the curl casting shadow.
struct PageFlipModifier: ViewModifier {
    /// Animation progress from 0 (flat) to 1 (fully flipped).
    let progress: Double
    /// Whether a flip is actively in progress (reserved for future layer effects).
    let isFlipping: Bool

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(progress * -180),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.5
            )
            .opacity(progress > 0.5 ? 0 : 1)
            .shadow(
                color: .black.opacity(0.3 * (1 - progress)),
                radius: 8,
                x: -4,
                y: 0
            )
    }
}

// MARK: - View convenience

extension View {
    /// Attaches a `PageFlipModifier` to any view.
    func pageFlip(progress: Double, isFlipping: Bool) -> some View {
        modifier(PageFlipModifier(progress: progress, isFlipping: isFlipping))
    }
}

// MARK: - DragPageGesture

/// Encapsulates horizontal drag-to-flip gesture state and logic.
///
/// Usage — attach to the view that should respond to dragging:
/// ```swift
/// @StateObject private var gesture = DragPageGesture()
///
/// someView
///     .gesture(gesture.dragGesture(onSnap: { flipped in ... }))
///     .pageFlip(progress: gesture.progress, isFlipping: gesture.isFlipping)
/// ```
@MainActor
@Observable
final class DragPageGesture {
    // MARK: Observable state

    /// Current page-flip progress (0 = flat, 1 = flipped).
    var progress: Double = 0
    /// True while a drag is being tracked.
    var isFlipping: Bool = false

    // MARK: Private

    private let velocityThreshold: Double = 300   // points/second
    private var startTime: Date = .now
    private var startTranslation: CGFloat = 0

    // MARK: - Gesture builder

    /// Returns a `DragGesture` configured for right-to-left page flipping.
    ///
    /// - Parameters:
    ///   - screenWidth: Width used to normalise translation → progress. Defaults to the main screen width.
    ///   - onSnap: Called when the gesture settles. `true` = page flipped forward, `false` = snapped back.
    func dragGesture(
        screenWidth: CGFloat,
        onSnap: @escaping (Bool) -> Void
    ) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { [weak self] value in
                guard let self else { return }
                if !self.isFlipping {
                    self.isFlipping = true
                    self.startTime = .now
                    self.startTranslation = value.translation.width
                }

                // Right-to-left drag is negative translation → progress 0→1
                let delta = -(value.translation.width - self.startTranslation)
                let raw = delta / screenWidth
                self.progress = max(0, min(1, raw))
            }
            .onEnded { [weak self] value in
                guard let self else { return }
                self.isFlipping = false

                let elapsed = Date.now.timeIntervalSince(self.startTime)
                let velocity = elapsed > 0
                    ? Double(-value.translation.width) / elapsed
                    : 0

                let shouldFlip = velocity > self.velocityThreshold || self.progress > 0.5

                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    self.progress = shouldFlip ? 1 : 0
                }

                HapticManager.shared.softTap()
                onSnap(shouldFlip)
            }
    }

    /// Animates the page back to flat (progress = 0).
    func reset(animated: Bool = true) {
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                progress = 0
            }
        } else {
            progress = 0
        }
    }

    /// Animates the page to fully flipped (progress = 1).
    func flip(animated: Bool = true) {
        if animated {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                progress = 1
            }
        } else {
            progress = 1
        }
    }
}

// MARK: - Preview

#Preview {
    struct Demo: View {
        @State private var gesture = DragPageGesture()
        @State private var flipped = false

        var body: some View {
            ZStack {
                Color(red: 0.039, green: 0.059, blue: 0.118)
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.941, green: 0.910, blue: 0.855))
                    .frame(width: 260, height: 380)
                    .overlay(
                        Text(flipped ? "Flipped" : "Flat")
                            .foregroundStyle(.black)
                    )
                    .pageFlip(progress: gesture.progress, isFlipping: gesture.isFlipping)
                    .gesture(gesture.dragGesture(screenWidth: 300) { snapped in
                        flipped = snapped
                    })
            }
        }
    }
    return Demo()
}
