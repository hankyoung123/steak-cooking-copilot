import SwiftUI

struct AdvancedSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @State private var draft: SteakSetupPreferences
    let estimate: (SteakConfiguration) -> TimeInterval
    let targetTemperature: (Doneness) -> Double
    let onSave: (SteakSetupPreferences) -> Void

    init(
        preferences: SteakSetupPreferences,
        estimate: @escaping (SteakConfiguration) -> TimeInterval,
        targetTemperature: @escaping (Doneness) -> Double,
        onSave: @escaping (SteakSetupPreferences) -> Void
    ) {
        _draft = State(initialValue: preferences)
        self.estimate = estimate
        self.targetTemperature = targetTemperature
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
                    VStack(spacing: 0) {
                        valueRow("Target Temperature", value: targetText)
                            .padding(.vertical, 14)
                        settingDivider
                        valueRow("Estimated Time", value: durationText)
                            .padding(.vertical, 14)
                    }

                    Text("These settings are recommendations based on your last cook.")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.ink.opacity(0.42))
                        .padding(.top, 36)
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

            // Adaptive rather than one row of six: a single row needs ~46pt per
            // chip, and the sheet is not always 402pt wide — iOS presents it
            // inset on some devices, which clipped the last chip. The grid
            // resolves its column count from the width it is actually given, so
            // a chip can never fall outside the content area. Three per row at
            // every phone width, two only in a very narrow container.
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: Self.minimumChipWidth),
                        spacing: Self.chipSpacing
                    )
                ],
                spacing: Self.chipSpacing
            ) {
                ForEach(Self.thicknessChoices, id: \.self) { thickness in
                    thicknessChip(thickness)
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

    /// The narrowest a chip may render before the grid drops to fewer columns.
    /// The old single row could not honour this, which is what clipped `5.0`.
    private static let minimumChipWidth: CGFloat = 84
    private static let chipSpacing: CGFloat = 7
    private static let thicknessChoices: [Double] = [2.0, 2.5, 3.0, 3.5, 4.0, 5.0]

    private func thicknessChip(_ thickness: Double) -> some View {
        let isSelected = draft.configuration.thicknessCM == thickness

        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                draft.configuration.thicknessCM = thickness
            }
        } label: {
            Text(String(format: "%.1f", thickness))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.ink.opacity(isSelected ? 0.92 : 0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    isSelected ? theme.card.opacity(0.92) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? theme.butter : theme.ink.opacity(0.07),
                            lineWidth: 0.8
                        )
                }
        }
        .buttonStyle(EditorialPressStyle())
        .accessibilityIdentifier(
            String(format: "setup.thickness.%.1f", thickness)
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        String(
            format: "%.0f°C",
            targetTemperature(draft.configuration.doneness)
        )
    }

    /// Recomputed from the live draft so doneness/thickness changes are
    /// reflected immediately.
    private var durationText: String {
        let seconds = estimate(draft.configuration)
        let minutes = max(1, Int(ceil(seconds / 60)))
        return String(format: String(localized: "~%lld min"), Int64(minutes))
    }
}
