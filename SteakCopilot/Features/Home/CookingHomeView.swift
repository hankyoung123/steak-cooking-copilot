import SwiftUI

struct CookingHomeView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    topBar

                    SteakHeroCarousel(selection: cutBinding)
                        .frame(height: max(300, min(proxy.size.height * 0.40, 370)))
                        .accessibilityIdentifier("home.carousel")

                    cutNavigation
                        .padding(.horizontal, 28)
                        .padding(.top, 2)

                    VStack(spacing: 7) {
                        Text("TODAY’S CUT")
                            .quietEyebrowStyle(color: theme.ember)

                        Text(preferences.configuration.cut.title)
                            .textCase(.uppercase)
                            .editorialDisplayStyle(size: 48, color: theme.ink)
                            .minimumScaleFactor(0.72)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                    .padding(.top, 22)

                    planSummary
                        .padding(.horizontal, 28)
                        .padding(.top, 18)

                    estimateSummary
                        .padding(.horizontal, 28)
                        .padding(.top, 13)

                    PrimaryActionButton(
                        title: String(localized: "Begin Cooking"),
                        icon: "arrow.right"
                    ) {
                        controller.updateSetupPreferences(preferences)
                        controller.finishSetup()
                    }
                    .accessibilityIdentifier("setup.primary")
                    .accessibilityLabel(String(localized: "Begin Cooking →"))
                    .padding(.horizontal, 28)
                    .padding(.top, 18)

                    Button("Fine-tune settings") {
                        presentedSheet = .settings
                    }
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundStyle(theme.ink.opacity(0.68))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.ink.opacity(0.3))
                            .frame(height: 0.7)
                            .offset(y: 5)
                    }
                    .padding(.vertical, 15)
                    .buttonStyle(EditorialPressStyle())
                    .accessibilityIdentifier("home.settings")
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
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
                .presentationCornerRadius(28)
            case .history:
                CookLogView(records: controller.cookHistory)
                    .presentationDetents([.large])
                    .presentationCornerRadius(28)
            }
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.42),
            value: preferences.configuration.cut
        )
    }

    private var topBar: some View {
        HStack {
            Button("Cook history", systemImage: "clock.arrow.circlepath") {
                presentedSheet = .history
            }
            .labelStyle(.iconOnly)
            .accessibilityIdentifier("home.history")

            Spacer()

            Button("Settings", systemImage: "gearshape") {
                presentedSheet = .settings
            }
            .labelStyle(.iconOnly)
        }
        .font(.system(size: 18, weight: .light))
        .foregroundStyle(theme.ink.opacity(0.6))
        .padding(.horizontal, 28)
        .frame(height: 42)
    }

    private var cutNavigation: some View {
        HStack {
            Button {
                cutBinding.wrappedValue = previousCut
            } label: {
                neighborLabel(previousCut, arrow: "arrow.left", leadingArrow: true)
            }
            .buttonStyle(EditorialPressStyle())
            .accessibilityIdentifier("home.previousCut")

            Spacer()
            HStack(spacing: 8) {
                ForEach(SteakCut.allCases) { cut in
                    Circle()
                        .fill(cut == preferences.configuration.cut ? theme.butter : theme.ink.opacity(0.22))
                        .frame(width: 5, height: 5)
                }
            }
            Spacer()
            Button {
                cutBinding.wrappedValue = nextCut
            } label: {
                neighborLabel(nextCut, arrow: "arrow.right", leadingArrow: false)
            }
            .buttonStyle(EditorialPressStyle())
            .accessibilityIdentifier("home.nextCut")
        }
        .foregroundStyle(theme.ink.opacity(0.58))
    }

    private func neighborLabel(
        _ cut: SteakCut,
        arrow: String,
        leadingArrow: Bool
    ) -> some View {
        HStack(spacing: 6) {
            if leadingArrow { Image(systemName: arrow) }
            Text(cut.title.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(1.1)
            if !leadingArrow { Image(systemName: arrow) }
        }
        .font(.system(size: 10, weight: .light))
        .frame(width: 82, alignment: leadingArrow ? .leading : .trailing)
    }

    private var planSummary: some View {
        HStack(spacing: 0) {
            EditorialMetric(
                icon: "thermometer.medium",
                label: String(localized: "DONENESS"),
                value: preferences.configuration.doneness.title
            )
            Divider().frame(height: 44)
            EditorialMetric(
                icon: "ruler",
                label: String(localized: "THICKNESS"),
                value: String(format: "%.1f cm", preferences.configuration.thicknessCM)
            )
        }
    }

    private var estimateSummary: some View {
        VStack(spacing: 11) {
            EditorialHairline()
            HStack(spacing: 8) {
                Image(systemName: preferences.startingCondition == .fridge ? "snowflake" : "sun.max")
                Text(preferences.startingCondition.title)
                Text("·")
                Text(String(format: "%.0f°C", preferences.configuration.doneness.pullTemperatureC))
                Text("·")
                Text(durationText)
            }
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(theme.ink.opacity(0.48))
            EditorialHairline()
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

    private var previousCut: SteakCut {
        let cuts = SteakCut.allCases
        let index = cuts.firstIndex(of: preferences.configuration.cut) ?? 0
        return cuts[(index - 1 + cuts.count) % cuts.count]
    }

    private var nextCut: SteakCut {
        let cuts = SteakCut.allCases
        let index = cuts.firstIndex(of: preferences.configuration.cut) ?? 0
        return cuts[(index + 1) % cuts.count]
    }

    private var durationText: String {
        let minutes = max(1, Int(ceil(controller.currentProfile.estimatedCookingBudget / 60)))
        return String(format: String(localized: "~%lld min"), Int64(minutes))
    }
}

private enum HomeSheet: String, Identifiable {
    case settings
    case history
    var id: Self { self }
}
