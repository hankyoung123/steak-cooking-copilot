import SwiftUI

struct PrimaryActionButton: View {
    @Environment(AppTheme.self) private var theme
    let title: String
    var icon: String? = nil
    var isEnabled = true
    var lightOnDark = false
    /// Drawn over artwork rather than on its own band: the shadow deepens so the
    /// block still reads as a surface sitting above the photograph instead of as
    /// a printed block on a flat page.
    var floating = false
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
                // Printed black block on a flat page; a deeper, softer shadow when
                // it floats over the photograph, so it separates from the artwork.
                color: Color.black.opacity(
                    floating ? (lightOnDark ? 0.45 : 0.24) : (lightOnDark ? 0 : 0.12)
                ),
                radius: floating ? 18 : 6,
                y: floating ? 9 : 3
            )
        }
        .buttonStyle(EditorialPressStyle())
        .opacity(isEnabled ? 1 : 0.34)
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}
