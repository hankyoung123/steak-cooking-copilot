import Observation
import SwiftUI

@MainActor
@Observable
final class AppTheme {
    let porcelain = Color(red: 0.953, green: 0.937, blue: 0.906)
    let porcelainDeep = Color(red: 0.925, green: 0.894, blue: 0.848)
    let card = Color(red: 0.985, green: 0.975, blue: 0.955)
    let charcoal = Color(red: 0.071, green: 0.067, blue: 0.059)
    let charcoalLifted = Color(red: 0.12, green: 0.12, blue: 0.115)
    let ember = Color(red: 0.486, green: 0.188, blue: 0.157)
    let emberBright = Color(red: 0.84, green: 0.27, blue: 0.10)
    let butter = Color(red: 0.718, green: 0.596, blue: 0.400)
    let ink = Color(red: 0.085, green: 0.078, blue: 0.067)

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
}
