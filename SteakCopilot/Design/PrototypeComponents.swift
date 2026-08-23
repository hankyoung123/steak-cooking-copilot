import SwiftUI

struct StageTitle: View {
    let stage: CookingFlowStage

    var body: some View {
        VStack(spacing: 5) {
            Text(stage.title)
                .font(.caption.weight(.bold))
                .tracking(0.3)
            HStack(spacing: 3) {
                ForEach(CookingFlowStage.ordered.indices, id: \.self) { index in
                    Capsule()
                        .fill(dotColor(at: index))
                        .frame(
                            width: index == stage.index ? 11 : 5,
                            height: 4
                        )
                }
            }
            .animation(.easeOut(duration: 0.2), value: stage)
        }
        .accessibilityElement(children: .combine)
    }

    private func dotColor(at index: Int) -> Color {
        if index == stage.index {
            return stage == .cook ? .white : Color.accentColor
        }
        return .secondary.opacity(0.35)
    }
}

struct PrototypeCard<Content: View>: View {
    @Environment(AppTheme.self) private var theme
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.black.opacity(0.045), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 12, y: 5)
    }
}

struct PrototypeSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension CookingFlowStage {
    static let ordered: [Self] = [
        .setup, .prep, .heat, .cook, .finish, .eat, .feedback
    ]

    var index: Int {
        Self.ordered.firstIndex(of: self) ?? 0
    }

    var title: String {
        switch self {
        case .setup: String(localized: "SETUP")
        case .prep: String(localized: "PREP")
        case .heat: String(localized: "HEAT")
        case .cook: String(localized: "COOK")
        case .finish: String(localized: "FINISH")
        case .eat: String(localized: "EAT")
        case .feedback: String(localized: "FEEDBACK")
        }
    }
}
