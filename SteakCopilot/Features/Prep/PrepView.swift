import SwiftUI

struct PrepView: View {
    let controller: CookingSessionController
    @State private var dried = false
    @State private var salted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 18)

            Text("PREP")
                .quietEyebrowStyle(color: .primary)
            Text("Two quiet things\nbefore the heat.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            ZStack {
                SteakVisual(configuration: controller.session.configuration)
                    .saturation(dried ? 0.78 : 1)
                    .brightness(dried ? -0.03 : 0.08)
                    .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.5), value: dried)

                if salted {
                    SaltFeedback(reduceMotion: reduceMotion)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 38)

            VStack(spacing: 12) {
                PrepStep(
                    number: "01",
                    title: String(localized: "Pat it completely dry"),
                    detail: String(localized: "A dry surface builds a better crust."),
                    isComplete: dried
                ) { dried = true }
                .accessibilityIdentifier("prep.dry")

                PrepStep(
                    number: "02",
                    title: String(localized: "Salt both sides"),
                    detail: String(localized: "Evenly, edge to edge."),
                    isComplete: salted
                ) { salted = true }
                .accessibilityIdentifier("prep.salt")
            }

            Spacer()

            PrimaryActionButton(
                title: String(localized: "Heat the pan"),
                icon: "flame.fill",
                isEnabled: dried && salted
            ) {
                controller.finishPrep()
            }
            .accessibilityIdentifier("prep.continue")
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }
}

private struct PrepStep: View {
    let number: String
    let title: String
    let detail: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(number)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isComplete ? .green : .secondary)
            }
            .padding(16)
            .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

private struct SaltFeedback: View {
    let reduceMotion: Bool
    @State private var fallen = false

    var body: some View {
        ForEach(0..<14, id: \.self) { index in
            Circle()
                .fill(.white)
                .frame(width: 3, height: 3)
                .offset(
                    x: CGFloat((index * 29) % 150) - 75,
                    y: fallen || reduceMotion ? CGFloat((index * 17) % 70) - 15 : -100
                )
                .opacity(fallen || reduceMotion ? 0.76 : 0)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.72)) { fallen = true }
        }
    }
}
