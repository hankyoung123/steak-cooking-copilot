import SwiftUI

struct PrimaryActionButton: View {
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
            .frame(minHeight: 56)
            .foregroundStyle(lightOnDark ? Color.black : Color.white)
            .background(
                Capsule()
                    .fill(lightOnDark ? Color.white : Color(red: 0.16, green: 0.12, blue: 0.09))
            )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.34)
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}
