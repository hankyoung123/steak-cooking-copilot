import SwiftUI

struct SteakVisual: View {
    let configuration: SteakConfiguration
    var cookedProgress: Double = 0
    var sliced = false
    var showButter = false

    var body: some View {
        Group {
            if sliced {
                slicedSteak
            } else {
                wholeSteak
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var wholeSteak: some View {
        ZStack {
            SteakShape(cut: configuration.cut)
                .fill(meatGradient)

            SteakShape(cut: configuration.cut)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.36), .brown.opacity(0.45), .black.opacity(0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 5
                )

            SteakShape(cut: configuration.cut)
                .fill(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.56)],
                        center: .center,
                        startRadius: 16,
                        endRadius: 150
                    )
                )
                .opacity(min(max(cookedProgress, 0), 1))

            if configuration.cut == .ribeye {
                Ellipse()
                    .stroke(.white.opacity(0.46), lineWidth: 6)
                    .frame(width: 78, height: 46)
                    .rotationEffect(.degrees(-18))
                    .offset(x: 28, y: -6)
            }

            if showButter {
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.95), Color.orange.opacity(0.84)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 42, height: 24)
                    .rotationEffect(.degrees(12))
                    .offset(x: 74, y: -54)
                    .shadow(color: .orange.opacity(0.5), radius: 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .aspectRatio(1.48, contentMode: .fit)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 12)
    }

    private var slicedSteak: some View {
        HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(meatGradient)
                    .overlay(Capsule().stroke(.brown.opacity(0.7), lineWidth: 3))
                    .frame(width: 34 + Double(index % 2) * 4, height: 132 - Double(abs(index - 3)) * 7)
                    .rotationEffect(.degrees(Double(index - 3) * 2.5))
                    .offset(y: Double(abs(index - 3)) * 3)
            }
        }
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.2), radius: 16, y: 10)
    }

    private var meatGradient: LinearGradient {
        let center: Color
        switch configuration.doneness {
        case .rare: center = Color(red: 0.72, green: 0.12, blue: 0.13)
        case .mediumRare: center = Color(red: 0.78, green: 0.25, blue: 0.22)
        case .medium: center = Color(red: 0.66, green: 0.34, blue: 0.27)
        }
        return LinearGradient(
            colors: [Color(red: 0.31, green: 0.10, blue: 0.06), center, Color(red: 0.23, green: 0.07, blue: 0.035)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accessibilityDescription: String {
        let state = sliced ? "sliced" : "whole"
        return "\(state) \(configuration.thicknessCM.formatted(.number.precision(.fractionLength(1)))) centimeter \(configuration.cut.title), \(configuration.doneness.title)"
    }
}

struct SteakShape: InsettableShape {
    let cut: SteakCut
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        switch cut {
        case .ribeye:
            path.move(to: CGPoint(x: r.minX + r.width * 0.13, y: r.midY))
            path.addCurve(
                to: CGPoint(x: r.midX, y: r.minY + r.height * 0.06),
                control1: CGPoint(x: r.minX + r.width * 0.05, y: r.minY + r.height * 0.21),
                control2: CGPoint(x: r.minX + r.width * 0.30, y: r.minY)
            )
            path.addCurve(
                to: CGPoint(x: r.maxX - r.width * 0.04, y: r.midY),
                control1: CGPoint(x: r.maxX - r.width * 0.18, y: r.minY),
                control2: CGPoint(x: r.maxX, y: r.minY + r.height * 0.24)
            )
            path.addCurve(
                to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.04),
                control1: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.10),
                control2: CGPoint(x: r.maxX - r.width * 0.26, y: r.maxY)
            )
            path.addCurve(
                to: CGPoint(x: r.minX + r.width * 0.13, y: r.midY),
                control1: CGPoint(x: r.minX + r.width * 0.20, y: r.maxY),
                control2: CGPoint(x: r.minX, y: r.maxY - r.height * 0.20)
            )
        case .strip:
            path.addRoundedRect(in: r, cornerSize: CGSize(width: r.height * 0.28, height: r.height * 0.28))
        case .tenderloin:
            path.addEllipse(in: r.insetBy(dx: r.width * 0.12, dy: 0))
        }
        return path
    }

    func inset(by amount: CGFloat) -> SteakShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

#Preview("Configured steak") {
    SteakVisual(
        configuration: .init(cut: .ribeye, thicknessCM: 3.5, doneness: .mediumRare),
        cookedProgress: 0.72,
        showButter: true
    )
    .padding(40)
    .background(Color(red: 0.97, green: 0.93, blue: 0.84))
}
