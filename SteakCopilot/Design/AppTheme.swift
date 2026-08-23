import Observation
import SwiftUI

@MainActor
@Observable
final class AppTheme {
    let porcelain = Color(red: 0.965, green: 0.951, blue: 0.925)
    let porcelainDeep = Color(red: 0.925, green: 0.894, blue: 0.848)
    let card = Color(red: 0.985, green: 0.975, blue: 0.955)
    let charcoal = Color(red: 0.055, green: 0.055, blue: 0.052)
    let charcoalLifted = Color(red: 0.12, green: 0.12, blue: 0.115)
    let ember = Color(red: 0.69, green: 0.19, blue: 0.08)
    let emberBright = Color(red: 0.84, green: 0.27, blue: 0.10)
    let butter = Color(red: 0.92, green: 0.61, blue: 0.08)
    let ink = Color(red: 0.085, green: 0.078, blue: 0.067)

    var cream: Color { porcelain }
    var creamDeep: Color { porcelainDeep }

    func background(for stage: CookingFlowStage) -> Color {
        stage == .cook ? charcoal : porcelain
    }

    func foreground(for stage: CookingFlowStage) -> Color {
        stage == .cook ? porcelain : ink
    }
}

extension View {
    func quietEyebrowStyle(color: Color) -> some View {
        font(.caption.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(color.opacity(0.68))
    }
}
