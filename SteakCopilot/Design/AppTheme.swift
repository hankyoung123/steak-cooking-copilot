import Observation
import SwiftUI

@MainActor
@Observable
final class AppTheme {
    let porcelain = Color(red: 0.956, green: 0.936, blue: 0.895)
    let porcelainDeep = Color(red: 0.906, green: 0.875, blue: 0.816)
    let card = Color(red: 0.976, green: 0.959, blue: 0.923)
    let charcoal = Color(red: 0.075, green: 0.075, blue: 0.068)
    let charcoalLifted = Color(red: 0.125, green: 0.12, blue: 0.108)
    let ember = Color(red: 0.486, green: 0.188, blue: 0.157)
    let emberBright = Color(red: 0.84, green: 0.27, blue: 0.10)
    let butter = Color(red: 0.755, green: 0.641, blue: 0.426)
    let ink = Color(red: 0.098, green: 0.09, blue: 0.077)

    var cream: Color { porcelain }
    var creamDeep: Color { porcelainDeep }

    func background(for stage: CookingFlowStage) -> Color {
        [.prep, .heat, .cook, .finish].contains(stage) ? charcoal : porcelain
    }

    func foreground(for stage: CookingFlowStage) -> Color {
        [.prep, .heat, .cook, .finish].contains(stage) ? porcelain : ink
    }
}

enum AppSpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 16
    static let md: CGFloat = 28
    static let lg: CGFloat = 48
    static let xl: CGFloat = 72
}

extension View {
    func quietEyebrowStyle(color: Color) -> some View {
        font(.caption.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(color.opacity(0.68))
    }

    func editorialDisplayStyle(
        size: CGFloat,
        color: Color = .primary
    ) -> some View {
        font(.system(size: size, weight: .regular, design: .serif))
            .tracking(-0.45)
            .foregroundStyle(color)
    }
}
