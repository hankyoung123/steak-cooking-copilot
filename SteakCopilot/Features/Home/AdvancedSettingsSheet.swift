import SwiftUI

struct AdvancedSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @State private var draft: SteakSetupPreferences
    let estimatedSeconds: TimeInterval
    let onSave: (SteakSetupPreferences) -> Void

    init(
        preferences: SteakSetupPreferences,
        estimatedSeconds: TimeInterval,
        onSave: @escaping (SteakSetupPreferences) -> Void
    ) {
        _draft = State(initialValue: preferences)
        self.estimatedSeconds = estimatedSeconds
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(draft.configuration.cut.title)
                        .font(.system(size: 42, weight: .semibold, design: .serif))

                    settingsSection("Doneness") {
                        HStack(alignment: .top, spacing: 5) {
                            ForEach(Doneness.allCases) { doneness in
                                Button {
                                    draft.configuration.doneness = doneness
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(doneness.assetName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 44)
                                        Text(doneness.title)
                                            .font(.caption2.weight(.medium))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 82)
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(draft.configuration.doneness == doneness ? theme.ember : .clear)
                                            .frame(height: 2)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("setup.doneness.\(doneness.rawValue)")
                                .accessibilityAddTraits(draft.configuration.doneness == doneness ? .isSelected : [])
                            }
                        }
                    }

                    settingsSection("Thickness") {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach([2.5, 3.0, 4.0, 5.0], id: \.self) { thickness in
                                Button(String(format: "%.1f cm", thickness)) {
                                    draft.configuration.thicknessCM = thickness
                                }
                                .buttonStyle(.bordered)
                                .tint(draft.configuration.thicknessCM == thickness ? theme.ember : theme.ink.opacity(0.34))
                            }
                        }
                        Slider(value: $draft.configuration.thicknessCM, in: 2...5, step: 0.5)
                            .tint(theme.ember)
                            .accessibilityIdentifier("setup.thickness")
                    }

                    settingsSection("Starting temperature") {
                        HStack(spacing: 0) {
                            ForEach(StartingCondition.allCases) { condition in
                                Button {
                                    draft.startingCondition = condition
                                } label: {
                                    Text(condition.title)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundStyle(draft.startingCondition == condition ? theme.ink : .secondary)
                                        .overlay(alignment: .bottom) {
                                            Rectangle()
                                                .fill(draft.startingCondition == condition ? theme.ember : theme.ink.opacity(0.12))
                                                .frame(height: draft.startingCondition == condition ? 2 : 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    settingsSection("Cooking estimate") {
                        HStack {
                            metric(
                                title: "Pull target",
                                value: String(
                                    format: "%.0f°C",
                                    draft.configuration.doneness.pullTemperatureC
                                )
                            )
                            Spacer()
                            metric(title: "Estimated time", value: durationText)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
            .background(theme.porcelain)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: String(localized: "Save & Close")) {
                    onSave(draft)
                    dismiss()
                }
                .accessibilityIdentifier("settings.save")
                .padding(AppSpacing.sm)
                .background(theme.porcelain)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func settingsSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func metric(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
        }
    }

    private var durationText: String {
        let minutes = max(1, Int(ceil(estimatedSeconds / 60)))
        return String(format: String(localized: "~%lld min"), Int64(minutes))
    }
}
