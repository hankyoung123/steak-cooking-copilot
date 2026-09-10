import SwiftUI

/// Development-only Tuning Lab.
///
/// Shows the override chain (production → local override → effective) and
/// lets a developer change, save, reset, export and import parameters without
/// editing `Config/production.yaml` or shipping anything.
///
/// Reachable only when the app is launched with `-tuningLab`, so it can never
/// appear in a normal user flow. Accessibility identifiers stay stable because
/// they are part of the test contract.
struct TuningLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    let store: TuningStore
    let onApply: (AppTuning) -> Void

    @State private var draft: AppTuning
    @State private var exportedJSON: String?
    @State private var importError: String?

    init(store: TuningStore, onApply: @escaping (AppTuning) -> Void) {
        self.store = store
        self.onApply = onApply
        _draft = State(initialValue: store.effective)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    LabeledContent(
                        "Production defaults",
                        value: store.hasOverride ? "overridden" : "active"
                    )
                    LabeledContent(
                        "Local override",
                        value: store.hasOverride ? "active" : "none"
                    )
                    Text(ProductionTuning.sourceFingerprint.prefix(16) + "…")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("tuningLab.fingerprint")
                }

                Section("Cooking") {
                    stepper(
                        "Base budget",
                        value: $draft.cooking.baseCookingBudget,
                        step: 10,
                        range: 60...1800,
                        identifier: "tuningLab.baseBudget"
                    )
                    stepper(
                        "Flip interval (standard)",
                        value: $draft.cooking.flipIntervalStandard,
                        step: 1,
                        range: 5...180,
                        identifier: "tuningLab.flipIntervalStandard"
                    )
                    stepper(
                        "Late stage ratio",
                        value: $draft.cooking.lateStageRatio,
                        step: 0.01,
                        range: 0.1...0.95,
                        identifier: "tuningLab.lateStageRatio"
                    )
                }

                Section("Calibration") {
                    stepper(
                        "Doneness step",
                        value: $draft.calibration.donenessStepSeconds,
                        step: 1,
                        range: 0...120,
                        identifier: "tuningLab.donenessStep"
                    )
                    stepper(
                        "Crust step",
                        value: $draft.calibration.crustStepSeconds,
                        step: 1,
                        range: 0...120,
                        identifier: "tuningLab.crustStep"
                    )
                }

                Section("JSON override") {
                    Button("Export JSON") {
                        exportedJSON = store
                            .exportJSON()
                            .flatMap { String(data: $0, encoding: .utf8) }
                    }
                    .accessibilityIdentifier("tuningLab.export")

                    Button("Import JSON from export") {
                        guard let json = exportedJSON,
                              let data = json.data(using: .utf8)
                        else {
                            importError = "Nothing exported yet"
                            return
                        }
                        if store.importJSON(data) {
                            draft = store.effective
                            onApply(store.effective)
                            importError = nil
                        } else {
                            importError = "Could not decode the JSON payload"
                        }
                    }
                    .accessibilityIdentifier("tuningLab.import")

                    if let exportedJSON {
                        Text(exportedJSON)
                            .font(.caption2.monospaced())
                            .lineLimit(6)
                            .accessibilityIdentifier("tuningLab.exportedJSON")
                    }
                    if let importError {
                        Text(importError)
                            .font(.caption)
                            .foregroundStyle(theme.ember)
                            .accessibilityIdentifier("tuningLab.importError")
                    }
                }
            }
            .navigationTitle("Tuning Lab")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("tuningLab.close")
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Reset to production") {
                        store.resetToProduction()
                        draft = store.effective
                        onApply(store.effective)
                    }
                    .accessibilityIdentifier("tuningLab.reset")

                    Button("Save override") {
                        store.applyAndSave(draft)
                        onApply(store.effective)
                    }
                    .accessibilityIdentifier("tuningLab.save")
                }
            }
        }
    }

    private func stepper(
        _ title: LocalizedStringKey,
        value: Binding<Double>,
        step: Double,
        range: ClosedRange<Double>,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(step >= 1 ? String(format: "%.0f", value.wrappedValue)
                               : String(format: "%.2f", value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(identifier).decrement")

                Button {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(identifier).increment")
            }
        }
    }
}
