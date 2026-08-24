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
        ZStack {
            EditorialCanvas(dark: false)

            ScrollView {
                VStack(spacing: 0) {
                    header
                    titleBlock
                    EditorialHairline().padding(.top, 18)
                    donenessSection
                    settingDivider
                    thicknessSection
                    settingDivider
                    startingTemperatureSection
                    settingDivider
                    valueRow("Target Temperature", value: targetText)
                    settingDivider
                    valueRow("Estimated Time", value: durationText)

                    Text("These settings are recommendations based on your last cook.")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.ink.opacity(0.42))
                        .padding(.top, 52)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: String(localized: "Save & Close")) {
                    onSave(draft)
                    dismiss()
                }
                .accessibilityIdentifier("settings.save")
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(theme.porcelain.opacity(0.96))
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            Button("Close", systemImage: "chevron.left") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .light))
                .accessibilityIdentifier("settings.close")
            Spacer()
        }
        .frame(height: 44)
    }

    private var titleBlock: some View {
        VStack(spacing: 5) {
            Text("TODAY’S CUT")
                .quietEyebrowStyle(color: theme.ember)
            Text(draft.configuration.cut.title)
                .textCase(.uppercase)
                .editorialDisplayStyle(size: 40, color: theme.ink)
        }
        .padding(.top, 4)
    }

    private var donenessSection: some View {
        VStack(spacing: 14) {
            valueRow("Doneness", value: draft.configuration.doneness.title)

            HStack(alignment: .top, spacing: 3) {
                ForEach(Doneness.allCases) { doneness in
                    Button {
                        withAnimation(.snappy(duration: 0.28)) {
                            draft.configuration.doneness = doneness
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Image(doneness.assetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .background(theme.porcelainDeep.opacity(0.55), in: Circle())
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .stroke(
                                            draft.configuration.doneness == doneness
                                                ? theme.ember
                                                : theme.ink.opacity(0.12),
                                            lineWidth: draft.configuration.doneness == doneness ? 1.2 : 0.7
                                        )
                                }
                                .scaleEffect(draft.configuration.doneness == doneness ? 1.06 : 0.94)

                            Text(doneness.title)
                                .font(.system(size: 8, weight: .regular, design: .serif))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.68)
                                .foregroundStyle(theme.ink.opacity(0.74))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(EditorialPressStyle())
                    .accessibilityIdentifier("setup.doneness.\(doneness.rawValue)")
                    .accessibilityAddTraits(draft.configuration.doneness == doneness ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 15)
    }

    private var thicknessSection: some View {
        VStack(spacing: 12) {
            valueRow(
                "Thickness",
                value: String(format: "%.1f cm", draft.configuration.thicknessCM)
            )

            HStack(spacing: 7) {
                ForEach([2.0, 2.5, 3.0, 3.5, 4.0, 5.0], id: \.self) { thickness in
                    Button(String(format: "%.1f", thickness)) {
                        draft.configuration.thicknessCM = thickness
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.ink.opacity(0.72))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(
                        draft.configuration.thicknessCM == thickness
                            ? theme.card.opacity(0.92)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                draft.configuration.thicknessCM == thickness
                                    ? theme.butter
                                    : theme.ink.opacity(0.07),
                                lineWidth: 0.8
                            )
                    }
                    .buttonStyle(EditorialPressStyle())
                }
            }

            Slider(value: $draft.configuration.thicknessCM, in: 2...5, step: 0.5)
                .tint(theme.butter)
                .controlSize(.mini)
                .frame(height: 14)
                .accessibilityIdentifier("setup.thickness")
        }
        .padding(.vertical, 15)
    }

    private var startingTemperatureSection: some View {
        VStack(spacing: 12) {
            valueRow("Starting Temperature", value: draft.startingCondition.title)
            HStack(spacing: 10) {
                ForEach(StartingCondition.allCases) { condition in
                    Button {
                        draft.startingCondition = condition
                    } label: {
                        Text(condition.title)
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(
                                draft.startingCondition == condition
                                    ? theme.ink
                                    : theme.ink.opacity(0.46)
                            )
                            .background(
                                draft.startingCondition == condition
                                    ? theme.card.opacity(0.85)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        draft.startingCondition == condition
                                            ? theme.butter
                                            : theme.ink.opacity(0.05),
                                        lineWidth: 0.8
                                    )
                            }
                    }
                    .buttonStyle(EditorialPressStyle())
                }
            }
        }
        .padding(.vertical, 15)
    }

    private func valueRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .regular, design: .serif))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink.opacity(0.62))
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .light))
                .foregroundStyle(theme.ink.opacity(0.32))
        }
    }

    private var settingDivider: some View {
        EditorialHairline()
    }

    private var targetText: String {
        String(format: "%.0f°C", draft.configuration.doneness.targetTemperatureC)
    }

    private var durationText: String {
        let minutes = max(1, Int(ceil(estimatedSeconds / 60)))
        return String(format: String(localized: "~%lld min"), Int64(minutes))
    }
}
