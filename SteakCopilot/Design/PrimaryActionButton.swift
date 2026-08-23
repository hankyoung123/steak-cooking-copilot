import SwiftUI

struct PrimaryActionButton: View {
    @Environment(AppTheme.self) private var theme
    let title: String
    var icon: String? = nil
    var isEnabled = true
    var lightOnDark = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if let icon {
                    Image(systemName: icon)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .foregroundStyle(lightOnDark ? theme.ink : Color.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(lightOnDark ? Color.white : theme.ember)
            )
            .shadow(
                color: lightOnDark ? .clear : theme.ember.opacity(0.16),
                radius: 12,
                y: 6
            )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.34)
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}
