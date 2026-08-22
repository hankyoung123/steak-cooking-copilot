import SwiftUI

struct PanVisual: View {
    var isHeating = false
    var isCooking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.82))
                .frame(width: 130, height: 28)
                .offset(x: 130, y: 38)
                .rotationEffect(.degrees(12))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.18, green: 0.16, blue: 0.14), .black],
                        center: .center,
                        startRadius: 16,
                        endRadius: 145
                    )
                )
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 6))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 14)

            if isHeating || isCooking {
                heatWaves
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var heatWaves: some View {
        if reduceMotion {
            waves(raised: false)
        } else {
            PhaseAnimator([false, true]) { raised in
                waves(raised: raised)
            } animation: { _ in
                .easeInOut(duration: isCooking ? 1.8 : 2.8)
            }
        }
    }

    private func waves(raised: Bool) -> some View {
        HStack(spacing: 24) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .stroke(
                        LinearGradient(colors: [.clear, .orange.opacity(0.34), .clear], startPoint: .bottom, endPoint: .top),
                        lineWidth: 3
                    )
                    .frame(width: 14, height: 76)
                    .rotationEffect(.degrees(index == 1 ? 8 : -6))
                    .offset(y: raised ? -54 - Double(index) * 3 : -38)
                    .opacity(raised ? 0.18 : 0.5)
            }
        }
    }
}
