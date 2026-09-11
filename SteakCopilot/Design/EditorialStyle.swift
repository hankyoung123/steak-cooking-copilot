import SwiftUI

struct EditorialCanvas: View {
    let dark: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(
                    red: dark ? 0.075 : 0.956,
                    green: dark ? 0.075 : 0.936,
                    blue: dark ? 0.068 : 0.895
                )
                Image(dark ? "DarkTexture" : "PaperTexture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(dark ? 0.42 : 0.72)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct EditorialPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct EditorialHairline: View {
    @Environment(AppTheme.self) private var theme
    var dark = false

    var body: some View {
        Rectangle()
            .fill(dark ? Color.white.opacity(0.13) : theme.ink.opacity(0.12))
            .frame(height: 0.7)
    }
}

/// One column of the setup screen's parameter row.
///
/// Both columns are laid out identically — same icon box, same value slot, same
/// label treatment — so `三分熟` and `3.0 cm` carry comparable visual weight and
/// share one baseline. The icon sits in a fixed box rather than being sized to
/// its own glyph, because `thermometer.medium` and `ruler` have very different
/// natural proportions and would otherwise not read as a matched pair.
struct EditorialMetric: View {
    @Environment(AppTheme.self) private var theme
    let icon: String?
    let label: String
    let value: String
    var dark = false
    var valueIdentifier: String?

    var body: some View {
        VStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 16)
            }
            valueText
                .font(.system(size: 16, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 22)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(labelColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var valueText: some View {
        if let valueIdentifier {
            Text(value).accessibilityIdentifier(valueIdentifier)
        } else {
            Text(value)
        }
    }

    private var iconColor: Color {
        dark ? .white.opacity(0.5) : theme.ink.opacity(0.5)
    }

    private var valueColor: Color {
        dark ? .white.opacity(0.9) : theme.ink
    }

    private var labelColor: Color {
        dark ? .white.opacity(0.46) : theme.ink.opacity(0.55)
    }
}
