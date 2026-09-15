import SwiftUI

/// App-wide settings.
///
/// This is the screen behind the gear in the top-right corner. It is deliberately
/// **not** the same screen as the per-cook "Fine-tune settings" sheet: that one
/// edits the current steak's doneness and thickness, while everything here
/// applies across cooks.
///
/// The first — and for now only — setting is which cuts appear on the home
/// screen.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @State private var draft: AppPreferences
    let onSave: (AppPreferences) -> Void

    init(
        preferences: AppPreferences,
        onSave: @escaping (AppPreferences) -> Void
    ) {
        _draft = State(initialValue: preferences)
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
                    cutsSection
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: String(localized: "Save & Close")) {
                    onSave(draft)
                    dismiss()
                }
                .accessibilityIdentifier("appSettings.save")
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

    private var cutsSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("CUTS ON HOME")
                .quietEyebrowStyle(color: theme.ember)
                .padding(.bottom, 6)

            ForEach(SteakCut.allCases) { cut in
                cutRow(cut)
            }

            if isAnyCutLocked {
                Text("Keep at least one cut on the home screen.")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.ink.opacity(0.46))
                    .padding(.top, 4)
            }

            // One literal, not a concatenation: a `+` of two literals resolves
            // to `String`, which would pick the non-localizing `Text` overload.
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
        let locked = !draft.canHide(cut)
        return Toggle(
            isOn: Binding(
                get: { draft.isVisible(cut) },
                set: { draft.setCut(cut, visible: $0) }
            )
        ) {
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
        SteakCut.allCases.contains { !draft.canHide($0) }
    }
}
