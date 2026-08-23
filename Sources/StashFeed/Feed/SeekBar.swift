import SwiftUI

/// Thin Reels-style progress bar you can tap or drag anywhere along to seek - the touch target
/// (24pt tall) is taller than the visible line so it stays easy to grab. While dragging, a
/// thumb + timestamp are lifted well above the touch point (like a native iOS slider) so the
/// finger itself never hides them.
struct SeekBar: View {
    let progressFraction: Double
    let durationSeconds: Double?
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragFraction: Double = 0

    private let thumbDiameter: CGFloat = 18
    private let thumbLift: CGFloat = 44

    /// While dragging, track the touch position directly rather than waiting for
    /// `progressFraction` to come back through the parent's seek round-trip.
    private var displayFraction: Double {
        isDragging ? dragFraction : progressFraction
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * displayFraction, height: 3)

                if isDragging {
                    thumb(fraction: displayFraction)
                        .position(x: geometry.size.width * displayFraction, y: -thumbLift)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragFraction = min(max(value.location.x / geometry.size.width, 0), 1)
                        onSeek(dragFraction)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 24)
    }

    private func thumb(fraction: Double) -> some View {
        VStack(spacing: 4) {
            Text(timeLabel(fraction: fraction))
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .fixedSize()
            Circle()
                .fill(Color.white)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .shadow(radius: 2)
        }
    }

    private func timeLabel(fraction: Double) -> String {
        guard let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 else { return "--:--" }
        let seconds = Int((durationSeconds * fraction).rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
