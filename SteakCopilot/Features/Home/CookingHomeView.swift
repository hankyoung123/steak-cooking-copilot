import SwiftUI

/// The setup screen.
///
/// The whole screen is a fixed skeleton: `HomeLayoutMetrics` decides the
/// geometry of every band from the device size alone, and the selected cut only
/// changes what is *inside* a band. That is what stops `肉眼牛排` / `纽约客牛排` /
/// `菲力` (and `RIBEYE` / `NEW YORK STRIP` / `TENDERLOIN`) from reflowing the
/// title, the parameter row, the summary or the call to action.
///
/// The vertical rhythm comes from the resolved metrics' spacing tokens rather
/// than per-element padding, so the page reads top-to-bottom as one composition:
/// a generous hero, a tight title, a structured parameter row, a summary with
/// air, then a firm CTA and a quiet secondary action.
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
            let layout = HomeLayoutMetrics.resolve(for: proxy.size)
            ScrollView {
                skeleton(layout: layout)
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .settings:
                AdvancedSettingsSheet(
                    preferences: preferences,
                    estimate: { controller.estimatedCookingBudget(for: $0) },
                    targetTemperature: {
                        controller.tuning.doneness[$0].targetTemperatureC
                    },
                    onSave: save
                )
                .presentationDetents([.large])
                .presentationCornerRadius(28)
            case .history:
                CookLogView(
                    records: controller.cookHistory,
                    tuning: controller.tuning
                )
                    .presentationDetents([.large])
                    .presentationCornerRadius(28)
            }
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.42),
            value: preferences.configuration.cut
        )
    }

    // MARK: - Skeleton

    /// Slot order is fixed. The hero takes whatever the fixed bands leave over,
    /// so on a phone the page fills the screen exactly and every other band keeps
    /// one offset; the `Spacer` only absorbs slack on a container tall enough for
    /// the hero to reach its ceiling.
    private func skeleton(layout: HomeLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            topBar(layout)
            hero(layout)
            cutNavigation(layout)
                .padding(.top, layout.heroToNavigation)
            titleBlock(layout)
            planSummary(layout)
            estimateSummary(layout)
            Spacer(minLength: layout.summaryToPrimary)
            primaryAction(layout)
            secondaryAction(layout)
        }
    }

    private func topBar(_ layout: HomeLayoutMetrics) -> some View {
        HStack(spacing: 0) {
            utilityButton(
                title: String(localized: "Cook history"),
                systemImage: "clock.arrow.circlepath",
                identifier: "home.history"
            ) { presentedSheet = .history }

            Spacer(minLength: 0)

            utilityButton(
                title: String(localized: "Settings"),
                systemImage: "gearshape",
                identifier: "home.topSettings"
            ) { presentedSheet = .settings }
        }
        .padding(.horizontal, layout.screenInset)
        .frame(height: layout.topBarHeight)
    }

    private func hero(_ layout: HomeLayoutMetrics) -> some View {
        SteakHeroCarousel(selection: cutBinding, layout: layout)
            .frame(height: layout.heroHeight)
            .accessibilityIdentifier("home.carousel")
    }

    private func titleBlock(_ layout: HomeLayoutMetrics) -> some View {
        VStack(spacing: 7) {
            Text("TODAY’S CUT")
                .quietEyebrowStyle(color: theme.ember)

            Text(preferences.configuration.cut.title)
                .textCase(.uppercase)
                // 43pt: ~10% below the previous 48pt, so the artwork stays the
                // primary subject and the title confirms the cut instead of
                // competing with the photograph.
                .editorialDisplayStyle(size: 43, color: theme.ink)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .contentTransition(.opacity)
                .accessibilityIdentifier(HomeLayoutID.title)
        }
        .padding(.horizontal, layout.screenInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.titleHeight)
        .padding(.top, layout.navigationToTitle)
    }

    private func planSummary(_ layout: HomeLayoutMetrics) -> some View {
        HStack(spacing: 0) {
            EditorialMetric(
                icon: "thermometer.medium",
                label: String(localized: "DONENESS"),
                value: preferences.configuration.doneness.title,
                valueIdentifier: HomeLayoutID.planDoneness
            )

            // A hairline, not `Divider()`: the system divider is noticeably
            // heavier than every other rule on the screen.
            Rectangle()
                .fill(theme.ink.opacity(0.12))
                .frame(width: 0.7, height: 44)

            EditorialMetric(
                icon: "ruler",
                label: String(localized: "THICKNESS"),
                value: String(format: "%.1f cm", preferences.configuration.thicknessCM),
                valueIdentifier: HomeLayoutID.planThickness
            )
        }
        .padding(.horizontal, layout.screenInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.planHeight)
        .padding(.top, layout.titleToPlan)
    }

    /// The pre-flight summary. It carries real decision weight — how long, and
    /// to what temperature — so it is no longer styled as a footer caption: the
    /// base copy is a step darker and the pull temperature takes the brand warm
    /// accent. It stays one quiet line and never becomes a second headline.
    private func estimateSummary(_ layout: HomeLayoutMetrics) -> some View {
        VStack(spacing: 8) {
            EditorialHairline()
            HStack(spacing: 7) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .light))
                Text(durationText)
                    .font(.system(size: 12, weight: .regular))
                    .monospacedDigit()
                    .accessibilityIdentifier(HomeLayoutID.summary)
                Text("·")
                    .foregroundStyle(theme.ink.opacity(0.3))
                Text(pullTargetText)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(theme.ember.opacity(0.9))
                Text(String(localized: "Pull target"))
                    .font(.system(size: 12, weight: .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(theme.ink.opacity(0.66))
            EditorialHairline()
        }
        .padding(.horizontal, layout.screenInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.summaryHeight)
        .padding(.top, layout.planToSummary)
    }

    private func primaryAction(_ layout: HomeLayoutMetrics) -> some View {
        PrimaryActionButton(
            title: String(localized: "Begin Cooking"),
            icon: "arrow.right"
        ) {
            controller.updateSetupPreferences(preferences)
            controller.finishSetup()
        }
        .accessibilityIdentifier("setup.primary")
        .accessibilityLabel(String(localized: "Begin Cooking →"))
        .padding(.horizontal, layout.screenInset)
        .frame(height: layout.primaryActionHeight)
    }

    /// Deliberately not a second button: no fill, no border. It gains its
    /// affordance from a full-width touch target, a slightly stronger ink and a
    /// trailing arrow.
    private func secondaryAction(_ layout: HomeLayoutMetrics) -> some View {
        Button {
            presentedSheet = .settings
        } label: {
            HStack(spacing: 6) {
                Text("Fine-tune settings")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.ink.opacity(0.28))
                            .frame(height: 0.7)
                            .offset(y: 5)
                    }
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .light))
            }
            .foregroundStyle(theme.ink.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: layout.secondaryActionHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(EditorialPressStyle())
        .accessibilityIdentifier("home.settings")
        // The frame comes first so the 44pt band is the *content* height and the
        // spacing is added outside it. Applying the frame last would clamp the
        // tap target to 44 minus the spacing.
        .frame(height: layout.secondaryActionHeight)
        .padding(.horizontal, layout.screenInset)
        .padding(.top, layout.primaryToSecondary)
    }

    private func utilityButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                // Both utilities share one point size, weight and ink. The gear
                // carries more ink per unit area than the clock, so matching the
                // numbers is what makes the pair read as equally weighted; the
                // 44pt frame is the touch target and stays invisible.
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(theme.ink.opacity(0.62))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(EditorialPressStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Cut navigation

    private func cutNavigation(_ layout: HomeLayoutMetrics) -> some View {
        HStack(spacing: 0) {
            cutButton(
                previousCut,
                arrow: "arrow.left",
                leadingArrow: true,
                identifier: "home.previousCut",
                layout: layout
            ) { cutBinding.wrappedValue = previousCut }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                ForEach(SteakCut.allCases) { cut in
                    Circle()
                        .fill(
                            cut == preferences.configuration.cut
                                ? theme.butter
                                : theme.ink.opacity(0.2)
                        )
                        .frame(
                            width: cut == preferences.configuration.cut ? 6 : 5,
                            height: cut == preferences.configuration.cut ? 6 : 5
                        )
                        // Constant slot, so the animated dot cannot nudge the
                        // group off centre while it grows.
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            Spacer(minLength: 8)

            cutButton(
                nextCut,
                arrow: "arrow.right",
                leadingArrow: false,
                identifier: "home.nextCut",
                layout: layout
            ) { cutBinding.wrappedValue = nextCut }
        }
        .padding(.horizontal, layout.screenInset)
        .frame(maxWidth: layout.navigationMaxWidth)
        .frame(maxWidth: .infinity)
        .frame(height: layout.navigationHeight)
    }

    /// The whole side region is the target, not just the glyphs: the label sits
    /// in a fixed-width, full-height frame with an explicit content shape.
    private func cutButton(
        _ cut: SteakCut,
        arrow: String,
        leadingArrow: Bool,
        identifier: String,
        layout: HomeLayoutMetrics,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if leadingArrow {
                    Image(systemName: arrow)
                        .font(.system(size: 9, weight: .regular))
                }
                Text(cut.title.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.0)
                    .lineLimit(1)
                    // "NEW YORK STRIP" is the longest name in either language;
                    // it scales rather than truncating to "NEW YORK S…".
                    .minimumScaleFactor(0.6)
                if !leadingArrow {
                    Image(systemName: arrow)
                        .font(.system(size: 9, weight: .regular))
                }
            }
            .foregroundStyle(theme.ink.opacity(0.66))
            .frame(
                width: layout.navigationLabelWidth,
                height: layout.navigationHeight,
                alignment: leadingArrow ? .leading : .trailing
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EditorialPressStyle())
        .accessibilityIdentifier(identifier)
    }

    // MARK: - State

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

    private var pullTargetText: String {
        String(
            format: "%.0f°C",
            controller.tuning.doneness[
                preferences.configuration.doneness
            ].pullTemperatureC
        )
    }
}

private enum HomeSheet: String, Identifiable {
    case settings
    case history
    var id: Self { self }
}
