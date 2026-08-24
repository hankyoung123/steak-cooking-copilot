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
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                Spacer(minLength: 0)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(lightOnDark ? theme.ink : theme.butter)
                }
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .foregroundStyle(lightOnDark ? theme.ink : Color.white)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(lightOnDark ? theme.porcelain : theme.charcoalLifted)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(lightOnDark ? Color.white.opacity(0.24) : Color.white.opacity(0.07), lineWidth: 0.8)
            }
            .shadow(
                color: Color.black.opacity(lightOnDark ? 0 : 0.2),
                radius: 10,
                y: 5
            )
        }
        .buttonStyle(EditorialPressStyle())
        .opacity(isEnabled ? 1 : 0.34)
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}
