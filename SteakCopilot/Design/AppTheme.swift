import Observation
import SwiftUI

@MainActor
@Observable
final class AppTheme {
    let cream = Color(red: 0.97, green: 0.93, blue: 0.84)
    let creamDeep = Color(red: 0.91, green: 0.84, blue: 0.70)
    let charcoal = Color(red: 0.075, green: 0.065, blue: 0.055)
    let charcoalLifted = Color(red: 0.14, green: 0.115, blue: 0.09)
    let ember = Color(red: 0.82, green: 0.25, blue: 0.10)
    let butter = Color(red: 0.96, green: 0.70, blue: 0.20)
    let ink = Color(red: 0.13, green: 0.105, blue: 0.08)

    func background(for stage: CookingFlowStage) -> Color {
        stage == .cook ? charcoal : cream
    }

    func foreground(for stage: CookingFlowStage) -> Color {
        stage == .cook ? cream : ink
    }
}

extension View {
    func quietEyebrowStyle(color: Color) -> some View {
        font(.caption.weight(.semibold))
            .tracking(2.2)
            .foregroundStyle(color.opacity(0.62))
    }
}
