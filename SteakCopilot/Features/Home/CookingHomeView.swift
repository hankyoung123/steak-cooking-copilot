import SwiftUI

struct CookingHomeView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    @State private var preferences: SteakSetupPreferences
    @State private var presentedSheet: HomeSheet?

    init(controller: CookingSessionController) {
        self.controller = controller
        _preferences = State(
            initialValue: controller.setupPreferences(
                for: controller.session.configuration.cut
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("STEAK COPILOT")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.6)
                        Spacer()
                        Button("Cook history", systemImage: "clock.arrow.circlepath") {
                            presentedSheet = .history
                        }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .accessibilityIdentifier("home.history")
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.xs)

                    SteakHeroCarousel(selection: cutBinding)
                        .frame(height: max(300, min(proxy.size.height * 0.48, 440)))
                        .accessibilityIdentifier("home.carousel")

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("TODAY’S CUT")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)

                        Text(preferences.configuration.cut.title)
                            .font(.system(size: 52, weight: .semibold, design: .serif))
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                            .contentTransition(.numericText())

                        Text(configurationLine)
                            .font(.system(size: 17, weight: .medium))

                        Text(estimateLine)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)

                        PrimaryActionButton(title: String(localized: "Begin Cooking →")) {
                            controller.updateSetupPreferences(preferences)
                            controller.finishSetup()
                        }
                        .accessibilityIdentifier("setup.primary")
                        .padding(.top, AppSpacing.xs)

                        Button("Fine-tune settings") {
                            presentedSheet = .settings
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("home.settings")
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)
                }
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .settings:
                AdvancedSettingsSheet(
                    preferences: preferences,
                    estimatedSeconds: controller.currentProfile.estimatedCookingBudget,
                    onSave: save
                )
                .presentationDetents([.large])
            case .history:
                CookLogView(records: controller.cookHistory)
                    .presentationDetents([.large])
            }
        }
    }

    private var cutBinding: Binding<SteakCut> {
        Binding(
            get: { preferences.configuration.cut },
            set: { cut in
                guard cut != preferences.configuration.cut else { return }
                preferences = controller.setupPreferences(for: cut)
                controller.updateSetupPreferences(preferences)
            }
        )
    }

    private func save(_ newValue: SteakSetupPreferences) {
        preferences = newValue
        controller.updateSetupPreferences(newValue)
    }

    private var configurationLine: String {
        String(
            format: String(localized: "%@ · %.1f cm"),
            preferences.configuration.doneness.title,
            preferences.configuration.thicknessCM
        )
    }

    private var estimateLine: String {
        let minutes = max(1, Int(ceil(controller.currentProfile.estimatedCookingBudget / 60)))
        return String(
            format: String(localized: "%@ · Pull at %.0f°C · ~%lld min"),
            preferences.startingCondition.title,
            preferences.configuration.doneness.pullTemperatureC,
            Int64(minutes)
        )
    }
}

private enum HomeSheet: String, Identifiable {
    case settings
    case history
    var id: Self { self }
}
