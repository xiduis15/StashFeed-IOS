import SwiftUI

/// Thin Reels-style progress bar you can tap or drag anywhere along to seek - the touch target
/// (24pt tall) is taller than the visible line so it stays easy to grab.
struct SeekBar: View {
    let progressFraction: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * progressFraction, height: 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = min(max(value.location.x / geometry.size.width, 0), 1)
                        onSeek(fraction)
                    }
            )
        }
        .frame(height: 24)
    }
}
