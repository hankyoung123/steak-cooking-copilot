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

struct EditorialMetric: View {
    let icon: String?
    let label: String
    let value: String
    var dark = false

    var body: some View {
        VStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(dark ? Color.white.opacity(0.55) : Color.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(dark ? Color.white.opacity(0.43) : Color.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
