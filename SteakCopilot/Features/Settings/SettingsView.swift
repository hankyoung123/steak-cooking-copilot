import SwiftUI

/// App-wide settings.
///
/// This is the screen behind the gear in the top-right corner. It is deliberately
/// **not** the same screen as the per-cook "Fine-tune settings" sheet: that one
/// edits the current steak's doneness and thickness, while everything here
/// applies across cooks.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @State private var showsResetConfirmation = false

    let preferences: AppPreferences
    let learnedAdjustments: [LearnedAdjustment]
    /// Called as soon as a switch moves. There is no Save button, so a control
    /// that only edited a local draft would silently lose the change on close.
    let onChange: (AppPreferences) -> Void
    let onResetLearnedAdjustments: () -> Void

    init(
        preferences: AppPreferences,
        learnedAdjustments: [LearnedAdjustment],
        onChange: @escaping (AppPreferences) -> Void,
        onResetLearnedAdjustments: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.learnedAdjustments = learnedAdjustments
        self.onChange = onChange
        self.onResetLearnedAdjustments = onResetLearnedAdjustments
    }

    var body: some View {
        ZStack {
            EditorialCanvas(dark: false)

            ScrollView {
                VStack(spacing: 0) {
                    header
                    titleBlock
                    EditorialHairline().padding(.top, 18)
                    cutsSection
                    divider
                    remindersSection
                    divider
                    feedbackSection
                    divider
                    adjustmentsSection
                    divider
                    aboutSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.light)
        .alert(
            "Reset learned adjustments?",
            isPresented: $showsResetConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { onResetLearnedAdjustments() }
        } message: {
            // One literal: a `+` of two literals resolves to `String`, which
            // would pick the non-localizing `Text` overload.
            Text("The app will go back to its built-in timings for every cut. Your saved settings and cook history are kept.")
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Button("Close", systemImage: "chevron.left") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .light))
                .accessibilityIdentifier("appSettings.close")
            Spacer()
        }
        .frame(height: 44)
    }

    private var titleBlock: some View {
        Text(String(localized: "Settings"))
            .editorialDisplayStyle(size: 40, color: theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private var divider: some View {
        EditorialHairline().padding(.vertical, 4)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .quietEyebrowStyle(color: theme.ember)
            .padding(.bottom, 6)
    }

    // MARK: - Cuts

    private var cutsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("CUTS ON HOME")

            ForEach(SteakCut.allCases) { cut in
                cutRow(cut)
            }

            if isAnyCutLocked {
                Text("Keep at least one cut on the home screen.")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.ink.opacity(0.46))
                    .padding(.top, 4)
            }

            Text("Hiding a cut only takes it off the home screen. Its settings and everything it has learned are kept.")
                .font(.system(size: 9))
                .foregroundStyle(theme.ink.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .accessibilityIdentifier("appSettings.cuts.note")
        }
        .padding(.vertical, 16)
    }

    private func cutRow(_ cut: SteakCut) -> some View {
        let locked = !preferences.canHide(cut)
        return Toggle(isOn: visibilityBinding(cut)) {
            Text(cut.title)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
        }
        .tint(theme.butter)
        .disabled(locked)
        // The last visible cut cannot be turned off, so the reason has to be
        // visible rather than leaving a control that silently does nothing.
        .opacity(locked ? 0.4 : 1)
        .frame(minHeight: 46)
        .accessibilityIdentifier("appSettings.cut.\(cut.rawValue)")
    }

    private var isAnyCutLocked: Bool {
        SteakCut.allCases.contains { !preferences.canHide($0) }
    }

    /// Settings apply the moment they are changed, so the sheet never holds a
    /// draft that a close would discard.
    private func apply(_ updated: AppPreferences) {
        guard updated != preferences else { return }
        onChange(updated)
    }

    private func visibilityBinding(_ cut: SteakCut) -> Binding<Bool> {
        Binding(
            get: { preferences.isVisible(cut) },
            set: { visible in
                var updated = preferences
                updated.setCut(cut, visible: visible)
                apply(updated)
            }
        )
    }

    private func flagBinding(
        _ keyPath: WritableKeyPath<AppPreferences, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { preferences[keyPath: keyPath] },
            set: { value in
                var updated = preferences
                updated[keyPath: keyPath] = value
                apply(updated)
            }
        )
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("REMINDERS")
            toggleRow(
                "Cooking reminders",
                identifier: "appSettings.reminders",
                isOn: flagBinding(\.isNotificationsEnabled)
            )
            Text("Nudges you when the next flip, baste or pull is due, so you can step away from the pan.")
                .font(.system(size: 9))
                .foregroundStyle(theme.ink.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Sound and haptics

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("SOUND & HAPTICS")
            toggleRow(
                "Sound",
                identifier: "appSettings.sound",
                isOn: flagBinding(\.isSoundEnabled)
            )
            toggleRow(
                "Haptics",
                identifier: "appSettings.haptics",
                isOn: flagBinding(\.isHapticsEnabled)
            )
        }
        .padding(.vertical, 16)
    }

    // MARK: - Learned adjustments

    private var adjustmentsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("LEARNED ADJUSTMENTS")

            if learnedAdjustments.isEmpty {
                Text("Nothing yet. Feedback after a cook is what teaches the app.")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.ink.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("appSettings.adjustments.empty")
            } else {
                ForEach(learnedAdjustments) { adjustment in
                    adjustmentRow(adjustment)
                }

                Text("Learned from your feedback after a cook. Each entry shifts the timing for that cut, thickness and doneness.")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.ink.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                Button {
                    showsResetConfirmation = true
                } label: {
                    Text("Reset adjustments")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(theme.ember)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EditorialPressStyle())
                .accessibilityIdentifier("appSettings.resetAdjustments")
            }
        }
        .padding(.vertical, 16)
    }

    private func adjustmentRow(_ adjustment: LearnedAdjustment) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(adjustment.key.cut.title)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(
                    String(
                        format: String(localized: "%@ · %@"),
                        adjustment.key.thicknessBucket.title,
                        adjustment.key.doneness.title
                    )
                )
                .font(.system(size: 9))
                .foregroundStyle(theme.ink.opacity(0.46))
            }

            Spacer(minLength: 8)

            if adjustment.cookingTimeAdjustment != 0 {
                delta("TIME", adjustment.cookingTimeAdjustment)
            }
            if adjustment.searBiasAdjustment != 0 {
                delta("SEAR", adjustment.searBiasAdjustment)
            }
        }
        .frame(minHeight: 46)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            "appSettings.adjustment."
                + adjustment.key.cut.rawValue
                + "."
                + adjustment.key.doneness.rawValue
        )
    }

    private func delta(_ label: LocalizedStringKey, _ seconds: TimeInterval) -> some View {
        VStack(spacing: 3) {
            Text(Self.signedSeconds(seconds))
                .font(.system(size: 14, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(seconds > 0 ? theme.ember : theme.ink.opacity(0.7))
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(theme.ink.opacity(0.46))
        }
        .frame(minWidth: 44, alignment: .trailing)
    }

    /// `+30s` / `−15s`. A real minus sign, so a negative reads as a number
    /// rather than as prose.
    static func signedSeconds(_ seconds: TimeInterval) -> String {
        let rounded = Int(seconds.rounded())
        return "\(rounded < 0 ? "−" : "+")\(abs(rounded))s"
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("ABOUT")

            HStack {
                Text("Version")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(Self.version)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(theme.ink.opacity(0.62))
                    .accessibilityIdentifier("appSettings.version")
            }
            .frame(minHeight: 44)

            Text("Temperatures shown while cooking are model estimates, not measurements. They never decide when the steak is done.")
                .font(.system(size: 9))
                .foregroundStyle(theme.ink.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.vertical, 16)
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = info?["CFBundleVersion"] as? String, !build.isEmpty else {
            return short
        }
        return "\(short) (\(build))"
    }

    // MARK: - Shared row

    private func toggleRow(
        _ title: LocalizedStringKey,
        identifier: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(theme.ink)
        }
        .tint(theme.butter)
        .frame(minHeight: 46)
        .accessibilityIdentifier(identifier)
    }
}
