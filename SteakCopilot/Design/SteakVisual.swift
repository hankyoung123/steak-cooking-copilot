import SwiftUI

struct SteakVisual: View {
    let configuration: SteakConfiguration
    var cookedProgress: Double = 0
    var sliced = false
    var showButter = false

    var body: some View {
        Group {
            if sliced {
                Image(donenessAssetName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 26))
            } else {
                wholeSteak
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var wholeSteak: some View {
        ZStack {
            Image("SteakSurface")
                .resizable()
                .scaledToFill()
                .saturation(0.82 + normalizedProgress * 0.18)
                .brightness(-0.08 + normalizedProgress * 0.03)

            LinearGradient(
                colors: [.white.opacity(0.14), .clear, .black.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if showButter {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.yellow.opacity(0.88))
                    .frame(width: 42, height: 24)
                    .rotationEffect(.degrees(12))
                    .offset(x: 74, y: -54)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .clipShape(SteakShape(cut: configuration.cut))
        .aspectRatio(1.48, contentMode: .fit)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 12)
    }

    private var normalizedProgress: Double {
        min(max(cookedProgress, 0), 1)
    }

    private var donenessAssetName: String {
        switch configuration.doneness {
        case .rare: "DonenessRare"
        case .mediumRare: "DonenessMediumRare"
        case .medium: "DonenessMedium"
        }
    }

    private var accessibilityDescription: String {
        let state = sliced
            ? String(localized: "sliced")
            : String(localized: "whole")
        let thickness = configuration.thicknessCM.formatted(
            .number.precision(.fractionLength(1))
        )
        return String(
            format: String(localized: "%@ %@ centimeter %@, %@"),
            state,
            thickness,
            configuration.cut.title,
            configuration.doneness.title
        )
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
            path.addRoundedRect(
                in: r,
                cornerSize: CGSize(
                    width: r.height * 0.28,
                    height: r.height * 0.28
                )
            )
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

#Preview("Asset-based steak") {
    SteakVisual(
        configuration: .init(
            cut: .ribeye,
            thicknessCM: 3.5,
            doneness: .mediumRare
        ),
        cookedProgress: 0.72,
        showButter: true
    )
    .padding(40)
    .background(Color(red: 0.97, green: 0.93, blue: 0.84))
}
