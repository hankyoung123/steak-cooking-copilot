import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Development-only Tuning Lab.
///
/// Exposes **every** tunable parameter grouped by section, and applies edits to
/// the effective tuning immediately so a developer can watch the cook screen
/// react. Reachable only when the app is launched with `-tuningLab`, so it can
/// never appear in a normal user flow.
///
/// Accessibility identifiers are stable and part of the test contract:
/// `tuningLab.<field>` on the value, `.increment` / `.decrement` on the
/// controls.
struct TuningLabView: View {
    @Environment(\.dismiss) private var dismiss
    let store: TuningStore
    /// Called after the store changes so the session can re-derive its engine.
    let onApply: () -> Void

    @State private var draft: AppTuning
    @State private var importText = ""
    @State private var message: LabMessage?
    @State private var showsFileImporter = false
    /// Validation problems with the current draft. While this is non-empty the
    /// draft is ahead of the running configuration: editing continues, but the
    /// effective tuning stays at the last valid value.
    @State private var draftIssues: [String] = []
    /// Suppresses the live-apply hook while we set `draft` programmatically.
    @State private var isSyncingDraft = false

    init(store: TuningStore, onApply: @escaping () -> Void) {
        self.store = store
        self.onApply = onApply
        _draft = State(initialValue: store.effective)
    }

    var body: some View {
        NavigationStack {
            Form {
                sourceSection
                cookingSection
                cutsSection
                donenessSection
                calibrationSection
                finishingSection
                notificationsSection
                motionSection
                overrideSection
            }
            .navigationTitle("Tuning Lab")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("tuningLab.close")
                }
            }
            .safeAreaInset(edge: .bottom) { actions }
        }
        .onChange(of: draft) { _, newValue in
            guard !isSyncingDraft else { return }
            // Live apply, validated. A single parameter often cannot be set in
            // one step without passing through an illegal combination (for
            // example raising pullTemperatureC before lowering
            // targetTemperatureC), so a rejected draft is a normal state:
            // keep editing, leave the running configuration on the last valid
            // value, and show what is wrong.
            let outcome = store.applyValidated(newValue)
            draftIssues = outcome.issues
            onApply()
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case let .success(url):
                importFile(at: url)
            case let .failure(error):
                message = .failure("File import failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Sections

    private var sourceSection: some View {
        Section("Source") {
            LabeledContent("Production defaults", value: "production.yaml")
            LabeledContent("Running", value: store.stateDescription)
            LabeledContent(
                "Changed fields",
                value: "\(store.overriddenFieldCount)"
            )
            Text(ProductionTuning.sourceFingerprint.prefix(16) + "…")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("tuningLab.fingerprint")

            if !draftIssues.isEmpty {
                // The draft is not running: it failed validation, so the app is
                // still on the last valid configuration.
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "Draft not applied — \(draftIssues.count) issue(s)",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("tuningLab.validationWarning")

                    Text(draftIssues.joined(separator: "\n"))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("tuningLab.validationIssues")
                }
            }
        }
    }

    private var cookingSection: some View {
        Section("Cooking") {
            ForEach(Self.cookingFields) { field in
                numberRow(field)
            }
        }
    }

    private var cutsSection: some View {
        Section("Cuts") {
            ForEach(SteakCut.allCases) { cut in
                DisclosureGroup {
                    numberRow(
                        Self.number(
                            "\(cut.rawValue).budgetOffset",
                            "Cooking budget offset",
                            Self.cutKeyPath(cut).appending(path: \.cookingBudgetOffset),
                            step: 1, range: -180...180, decimals: 0
                        )
                    )
                    numberRow(
                        Self.number(
                            "\(cut.rawValue).recommendedThickness",
                            "Recommended thickness",
                            Self.cutKeyPath(cut).appending(path: \.recommendedThickness),
                            step: 0.5, range: 0.5...10, decimals: 1
                        )
                    )
                    Toggle("Needs fat cap", isOn: needsFatCapBinding(cut))
                        .accessibilityIdentifier(
                            "tuningLab.\(cut.rawValue).needsFatCap"
                        )

                    numberRow(
                        Self.number(
                            "\(cut.rawValue).basteMultiplier",
                            "Baste multiplier",
                            Self.cutKeyPath(cut).appending(path: \.basteMultiplier),
                            step: 0.05, range: 0.05...2, decimals: 2
                        )
                    )

                    if draft.cuts[cut].needsFatCap {
                        numberRow(
                            Self.optionalNumber(
                                "\(cut.rawValue).fatCapDuration",
                                "Fat cap duration (s)",
                                Self.cutKeyPath(cut).appending(path: \.fatCapDuration),
                                fallback: draft.cooking.minFatCapDuration,
                                step: 5, range: 1...600, decimals: 0
                            )
                        )
                    }
                } label: {
                    LabeledContent(
                        cut.title,
                        value: cutValueSummary(cut)
                    )
                }
            }
        }
    }

    private var donenessSection: some View {
        Section("Doneness") {
            ForEach(Doneness.allCases) { doneness in
                DisclosureGroup {
                    ForEach(Self.donenessFields(for: doneness)) { field in
                        numberRow(field)
                    }
                } label: {
                    LabeledContent(
                        doneness.title,
                        value: donenessValueSummary(doneness)
                    )
                }
            }
        }
    }

    private var calibrationSection: some View {
        Section("Calibration") {
            ForEach(Self.calibrationFields) { field in
                numberRow(field)
            }
        }
    }

    private var finishingSection: some View {
        Section("Finishing") {
            ForEach(Self.finishingFields) { field in
                numberRow(field)
            }
            DisclosureGroup("Doneness adjustments") {
                ForEach(Doneness.allCases) { doneness in
                    numberRow(
                        Self.number(
                            "finishing.doneness.\(doneness.rawValue)",
                            doneness.rawValue,
                            Self.finishingAdjustmentKeyPath(doneness),
                            step: 5, range: 0...300, decimals: 0
                        )
                    )
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            ForEach(Self.notificationFields) { field in
                numberRow(field)
            }
        }
    }

    private var motionSection: some View {
        Section("Motion") {
            ForEach(Self.motionDurationFields) { field in
                numberRow(field)
            }
            DisclosureGroup("Bounce") {
                ForEach(Self.motionBounceFields) { field in
                    numberRow(field)
                }
            }
        }
    }

    private var overrideSection: some View {
        Section("Override JSON") {
            HStack {
                Button("Export") { export() }
                    .accessibilityIdentifier("tuningLab.export")
                Spacer()
                if let json = store.exportJSONString() {
                    ShareLink(item: json) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("tuningLab.share")
                }
                Button("Copy") { copyExport() }
                    .accessibilityIdentifier("tuningLab.copy")
            }

            if let message, message.isFailure {
                // The complete, untruncated reason list.
                Text(message.text)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("tuningLab.detail")
            }

            // Import controls sit above the editor so they stay reachable
            // without scrolling through the text view.
            HStack {
                Button("Import pasted JSON") { importPasted() }
                    .accessibilityIdentifier("tuningLab.importPasted")
                Spacer()
                Button("Import file…") { showsFileImporter = true }
                    .accessibilityIdentifier("tuningLab.importFile")
            }

            TextEditor(text: $importText)
                .font(.caption.monospaced())
                .frame(minHeight: 100)
                .accessibilityIdentifier("tuningLab.importText")

        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            // Feedback lives here, not at the end of the form, so it is always
            // on screen after an action.
            if let message {
                // Deliberately capped: a growing bar would cover the last
                // section of the form. The full detail is shown in-section.
                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(message.isFailure ? Color.red : Color.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(
                        message.isFailure
                            ? "tuningLab.importError"
                            : "tuningLab.message"
                    )
            }
            HStack(spacing: 12) {
                Button("Reset to production") { reset() }
                    .accessibilityIdentifier("tuningLab.reset")
                Spacer()
                Button("Save override") { save() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tuningLab.save")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Rows

    private func numberRow(_ field: NumberFieldSpec) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(field.title)
                Spacer()
                Text(field.text(in: draft))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("tuningLab.\(field.id).value")
            }
            HStack(spacing: 14) {
                Button {
                    adjust(field, by: -field.step)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tuningLab.\(field.id).decrement")

                Button {
                    adjust(field, by: field.step)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tuningLab.\(field.id).increment")
            }
        }
    }

    // MARK: - Editing

    private func adjust(_ field: NumberFieldSpec, by delta: Double) {
        let next = field.clamped(field.get(draft) + delta)
        field.set(&draft, next)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func binding<V>(_ keyPath: WritableKeyPath<AppTuning, V>) -> Binding<V> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { newValue in
                draft[keyPath: keyPath] = newValue
            }
        )
    }

    /// Enabling a fat cap needs a duration. Rather than inventing a number it
    /// starts from the production value for that cut, which keeps the
    /// validator's "needsFatCap implies a duration" invariant satisfied.
    private func needsFatCapBinding(_ cut: SteakCut) -> Binding<Bool> {
        let needsFatCap = Self.cutKeyPath(cut).appending(path: \.needsFatCap)
        let fatCapDuration = Self.cutKeyPath(cut).appending(path: \.fatCapDuration)
        return Binding(
            get: { draft[keyPath: needsFatCap] },
            set: { isOn in
                draft[keyPath: needsFatCap] = isOn
                if isOn, draft[keyPath: fatCapDuration] == nil {
                    draft[keyPath: fatCapDuration] = store.production.cuts[cut]
                        .fatCapDuration ?? draft.cooking.minFatCapDuration
                }
            }
        )
    }

    private func cutValueSummary(_ cut: SteakCut) -> String {
        let spec = draft.cuts[cut]
        let baste = format(spec.basteMultiplier, decimals: 2)
        if spec.needsFatCap {
            let duration = format(spec.fatCapDuration ?? 0, decimals: 0)
            return "fat cap \(duration)s · baste ×\(baste)"
        }
        return "no fat cap · baste ×\(baste)"
    }

    private func donenessValueSummary(_ doneness: Doneness) -> String {
        let spec = draft.doneness[doneness]
        return "\(format(spec.pullTemperatureC, decimals: 0))"
            + "→\(format(spec.targetTemperatureC, decimals: 0))°C"
    }

    // MARK: - Override actions

    private func save() {
        do {
            // The store validates; an invalid draft cannot be persisted.
            try store.applyValidatedAndSave(draft)
            draftIssues = []
            message = .success(
                "Override saved (\(store.overriddenFieldCount) fields)."
            )
        } catch let error as TuningImportError {
            draftIssues = error.issues
            message = .failure(
                "Cannot save — fix these first:\n" + error.issues.joined(separator: "\n")
            )
        } catch {
            message = .failure(error.localizedDescription)
        }
    }

    private func reset() {
        store.resetToProduction()
        syncDraftFromStore()
        message = .success("Reset to production.yaml defaults.")
    }

    private func export() {
        guard let json = store.exportJSONString() else {
            message = .failure("Could not encode the override.")
            return
        }
        importText = json
        message = .success("Exported \(store.overriddenFieldCount) overridden fields.")
    }

    private func copyExport() {
        guard let json = store.exportJSONString() else {
            message = .failure("Could not encode the override.")
            return
        }
        UIPasteboard.general.string = json
        message = .success("Copied override JSON to the clipboard.")
    }

    private func importPasted() {
        guard !importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = .failure("Paste an override document first.")
            return
        }
        applyImport { try store.importJSON(importText) }
    }

    private func importFile(at url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        applyImport {
            let data = try Data(contentsOf: url)
            try store.importJSON(data)
        }
    }

    /// A rejected import leaves the existing override untouched and surfaces
    /// the reason instead of silently doing nothing.
    private func applyImport(_ operation: () throws -> Void) {
        do {
            try operation()
            syncDraftFromStore()
            message = .success(
                "Override imported (\(store.overriddenFieldCount) fields)."
            )
        } catch let error as TuningImportError {
            message = .failure(error.issues.joined(separator: "\n"))
        } catch {
            message = .failure(error.localizedDescription)
        }
    }

    private func syncDraftFromStore() {
        isSyncingDraft = true
        draft = store.effective
        draftIssues = []
        onApply()
        isSyncingDraft = false
    }

    private struct LabMessage {
        let text: String
        let isFailure: Bool

        static func success(_ text: String) -> LabMessage {
            LabMessage(text: text, isFailure: false)
        }

        static func failure(_ text: String) -> LabMessage {
            LabMessage(text: text, isFailure: true)
        }
    }
}

// MARK: - Field specifications

/// One editable number.
///
/// Accessors are closures rather than key paths so optional values (such as
/// `fatCapDuration`) are handled without unsafe key-path casting.
struct NumberFieldSpec: Identifiable {
    let id: String
    let title: String
    let step: Double
    let range: ClosedRange<Double>
    let decimals: Int
    let get: (AppTuning) -> Double
    let set: (inout AppTuning, Double) -> Void

    func text(in tuning: AppTuning) -> String {
        String(format: "%.\(decimals)f", get(tuning))
    }

    func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

extension TuningLabView {
    /// A number backed by a non-optional tuning field.
    static func number(
        _ id: String,
        _ title: String,
        _ keyPath: WritableKeyPath<AppTuning, Double>,
        step: Double,
        range: ClosedRange<Double>,
        decimals: Int
    ) -> NumberFieldSpec {
        NumberFieldSpec(
            id: id,
            title: title,
            step: step,
            range: range,
            decimals: decimals,
            get: { $0[keyPath: keyPath] },
            set: { $0[keyPath: keyPath] = $1 }
        )
    }

    /// A number backed by an optional tuning field. `fallback` is shown while
    /// the value is nil; editing it writes a concrete value.
    static func optionalNumber(
        _ id: String,
        _ title: String,
        _ keyPath: WritableKeyPath<AppTuning, Double?>,
        fallback: Double,
        step: Double,
        range: ClosedRange<Double>,
        decimals: Int
    ) -> NumberFieldSpec {
        NumberFieldSpec(
            id: id,
            title: title,
            step: step,
            range: range,
            decimals: decimals,
            get: { $0[keyPath: keyPath] ?? fallback },
            set: { $0[keyPath: keyPath] = $1 }
        )
    }

    static var cookingFields: [NumberFieldSpec] {
        [
            number("cooking.baseCookingBudget", "Base cooking budget (s)", \.cooking.baseCookingBudget, step: 10, range: 30...1800, decimals: 0),
            number("cooking.referenceThickness", "Reference thickness (cm)", \.cooking.referenceThickness, step: 0.1, range: 0.5...10, decimals: 2),
            number("cooking.minThicknessFactor", "Min thickness factor", \.cooking.minThicknessFactor, step: 0.01, range: 0.01...1, decimals: 2),
            number("cooking.minCookingBudget", "Min cooking budget (s)", \.cooking.minCookingBudget, step: 10, range: 10...1800, decimals: 0),
            number("cooking.maxCookingBudget", "Max cooking budget (s)", \.cooking.maxCookingBudget, step: 10, range: 10...3600, decimals: 0),
            number("cooking.flipIntervalThin", "Flip interval · thin (s)", \.cooking.flipIntervalThin, step: 1, range: 1...300, decimals: 0),
            number("cooking.flipIntervalStandard", "Flip interval · standard (s)", \.cooking.flipIntervalStandard, step: 1, range: 1...300, decimals: 0),
            number("cooking.flipIntervalThick", "Flip interval · thick (s)", \.cooking.flipIntervalThick, step: 1, range: 1...300, decimals: 0),
            number("cooking.flipIntervalStandardMaxThickness", "Standard cadence max thickness (cm)", \.cooking.flipIntervalStandardMaxThickness, step: 0.1, range: 0.5...10, decimals: 1),
            number("cooking.minFlipInterval", "Min flip interval (s)", \.cooking.minFlipInterval, step: 0.1, range: 0.1...5, decimals: 1),
            number("cooking.minBudgetInFlipIntervals", "Min budget in flip intervals", \.cooking.minBudgetInFlipIntervals, step: 1, range: 1...20, decimals: 0),
            number("cooking.thinMaxThickness", "Thin max thickness (cm)", \.cooking.thinMaxThickness, step: 0.1, range: 0.1...10, decimals: 1),
            number("cooking.standardMaxThickness", "Standard max thickness (cm)", \.cooking.standardMaxThickness, step: 0.1, range: 0.1...10, decimals: 1),
            number("cooking.lateStageRatio", "Late stage ratio", \.cooking.lateStageRatio, step: 0.01, range: 0.05...0.95, decimals: 2),
            number("cooking.lateStageMinFlipIntervals", "Late stage min flip intervals", \.cooking.lateStageMinFlipIntervals, step: 1, range: 1...20, decimals: 0),
            number("cooking.basteRatio", "Baste ratio", \.cooking.basteRatio, step: 0.01, range: 0.01...1, decimals: 2),
            number("cooking.minBasteDuration", "Min baste duration (s)", \.cooking.minBasteDuration, step: 0.1, range: 0.1...600, decimals: 1),
            number("cooking.maxBasteDuration", "Max baste duration (s)", \.cooking.maxBasteDuration, step: 1, range: 1...1200, decimals: 0),
            number("cooking.budgetFinishAdjustmentRatio", "Budget finish adjustment ratio", \.cooking.budgetFinishAdjustmentRatio, step: 0.01, range: 0...1, decimals: 2),
            number("cooking.budgetFinishAdjustmentMinSeconds", "Budget finish adjustment min (s)", \.cooking.budgetFinishAdjustmentMinSeconds, step: 1, range: -600...0, decimals: 0),
            number("cooking.budgetFinishAdjustmentMaxSeconds", "Budget finish adjustment max (s)", \.cooking.budgetFinishAdjustmentMaxSeconds, step: 1, range: 0...600, decimals: 0),
            number("cooking.minFatCapDuration", "Min fat cap duration (s)", \.cooking.minFatCapDuration, step: 0.5, range: 0.1...600, decimals: 1),
        ]
    }

    static func donenessFields(for doneness: Doneness) -> [NumberFieldSpec] {
        let prefix = "doneness.\(doneness.rawValue)"
        let base = donenessKeyPath(doneness)
        return [
            number("\(prefix).pull", "Pull temp (°C)", base.appending(path: \.pullTemperatureC), step: 1, range: 20...100, decimals: 0),
            number("\(prefix).target", "Target temp (°C)", base.appending(path: \.targetTemperatureC), step: 1, range: 30...100, decimals: 0),
            number("\(prefix).factor", "Budget factor", base.appending(path: \.cookingBudgetFactor), step: 0.01, range: 0.1...3, decimals: 2),
        ]
    }

    static func donenessKeyPath(
        _ doneness: Doneness
    ) -> WritableKeyPath<AppTuning, DonenessSpecTuning> {
        switch doneness {
        case .rare: \.doneness.rare
        case .mediumRare: \.doneness.mediumRare
        case .medium: \.doneness.medium
        case .mediumWell: \.doneness.mediumWell
        case .wellDone: \.doneness.wellDone
        }
    }

    static func finishingAdjustmentKeyPath(
        _ doneness: Doneness
    ) -> WritableKeyPath<AppTuning, Double> {
        switch doneness {
        case .rare: \.finishing.donenessAdjustment.rare
        case .mediumRare: \.finishing.donenessAdjustment.mediumRare
        case .medium: \.finishing.donenessAdjustment.medium
        case .mediumWell: \.finishing.donenessAdjustment.mediumWell
        case .wellDone: \.finishing.donenessAdjustment.wellDone
        }
    }

    static func cutKeyPath(_ cut: SteakCut) -> WritableKeyPath<AppTuning, CutSpecTuning> {
        switch cut {
        case .ribeye: \.cuts.ribeye
        case .strip: \.cuts.strip
        case .tenderloin: \.cuts.tenderloin
        }
    }

    static var calibrationFields: [NumberFieldSpec] {
        [
            number("calibration.donenessStepSeconds", "Doneness step (s)", \.calibration.donenessStepSeconds, step: 1, range: 1...120, decimals: 0),
            number("calibration.crustStepSeconds", "Crust step (s)", \.calibration.crustStepSeconds, step: 1, range: 1...120, decimals: 0),
            number("calibration.maxCookingAdjustment", "Max cooking adjustment (s)", \.calibration.maxCookingAdjustment, step: 5, range: 1...600, decimals: 0),
            number("calibration.maxSearAdjustment", "Max sear adjustment (s)", \.calibration.maxSearAdjustment, step: 1, range: 1...600, decimals: 0),
        ]
    }

    static var finishingFields: [NumberFieldSpec] {
        [
            number("finishing.baseAdjustmentSeconds", "Base adjustment (s)", \.finishing.baseAdjustmentSeconds, step: 5, range: 0...600, decimals: 0),
            number("finishing.thicknessAdjustmentPerCM", "Thickness adjustment per cm (s)", \.finishing.thicknessAdjustmentPerCM, step: 1, range: 0...120, decimals: 0),
            number("finishing.spreadSeconds", "Spread (s)", \.finishing.spreadSeconds, step: 5, range: 1...900, decimals: 0),
            number("finishing.minLowerBoundSeconds", "Min lower bound (s)", \.finishing.minLowerBoundSeconds, step: 1, range: 1...600, decimals: 0),
            number("finishing.minUpperBoundSeconds", "Min upper bound (s)", \.finishing.minUpperBoundSeconds, step: 1, range: 1...600, decimals: 0),
            number("finishing.carryoverMinC", "Carryover min (°C)", \.finishing.carryoverMinC, step: 0.5, range: 0...20, decimals: 1),
            number("finishing.carryoverMaxC", "Carryover max (°C)", \.finishing.carryoverMaxC, step: 0.5, range: 0...20, decimals: 1),
            number("finishing.remainingRiseSecondsPerDegree", "Seconds per remaining degree", \.finishing.remainingRiseSecondsPerDegree, step: 0.5, range: 0...60, decimals: 1),
            number("finishing.maxManualAdjustmentSeconds", "Max manual adjustment (s)", \.finishing.maxManualAdjustmentSeconds, step: 5, range: 0...600, decimals: 0),
            number("finishing.idleEstimateMinSeconds", "Idle estimate min (s)", \.finishing.idleEstimateMinSeconds, step: 5, range: 1...1800, decimals: 0),
            number("finishing.idleEstimateMaxSeconds", "Idle estimate max (s)", \.finishing.idleEstimateMaxSeconds, step: 5, range: 1...1800, decimals: 0),
        ]
    }

    static var notificationFields: [NumberFieldSpec] {
        [
            number("notifications.approachingThresholdSeconds", "Approaching threshold (s)", \.notifications.approachingThresholdSeconds, step: 1, range: 1...60, decimals: 0),
            number("notifications.urgentThresholdSeconds", "Urgent threshold (s)", \.notifications.urgentThresholdSeconds, step: 1, range: 1...60, decimals: 0),
            number("notifications.hapticLightSeconds", "Light haptic at (s)", \.notifications.hapticLightSeconds, step: 1, range: 1...30, decimals: 0),
            number("notifications.hapticHeavySeconds", "Heavy haptic at (s)", \.notifications.hapticHeavySeconds, step: 1, range: 0...30, decimals: 0),
            number("notifications.staleDelaySeconds", "Live Activity stale delay (s)", \.notifications.staleDelaySeconds, step: 5, range: 1...600, decimals: 0),
            number("notifications.finishedDismissalSeconds", "Finished dismissal (s)", \.notifications.finishedDismissalSeconds, step: 5, range: 1...600, decimals: 0),
            number("notifications.cancelledDismissalSeconds", "Cancelled dismissal (s)", \.notifications.cancelledDismissalSeconds, step: 1, range: 1...600, decimals: 0),
        ]
    }

    static var motionDurationFields: [NumberFieldSpec] {
        [
            number("motion.subtle", "subtle (s)", \.motion.subtle, step: 0.01, range: 0...10, decimals: 2),
            number("motion.responsive", "responsive (s)", \.motion.responsive, step: 0.01, range: 0...10, decimals: 2),
            number("motion.emphasis", "emphasis (s)", \.motion.emphasis, step: 0.01, range: 0...10, decimals: 2),
            number("motion.action", "action (s)", \.motion.action, step: 0.01, range: 0...10, decimals: 2),
            number("motion.cinematic", "cinematic (s)", \.motion.cinematic, step: 0.01, range: 0...10, decimals: 2),
            number("motion.stageTransition", "stage transition (s)", \.motion.stageTransition, step: 0.01, range: 0...10, decimals: 2),
            number("motion.flipLift", "flip lift (s)", \.motion.flipLift, step: 0.01, range: 0...10, decimals: 2),
            number("motion.flipRotate", "flip rotate (s)", \.motion.flipRotate, step: 0.01, range: 0...10, decimals: 2),
            number("motion.flipLand", "flip land (s)", \.motion.flipLand, step: 0.01, range: 0...10, decimals: 2),
            number("motion.flipSettle", "flip settle (s)", \.motion.flipSettle, step: 0.01, range: 0...10, decimals: 2),
            number("motion.compactFlipOut", "compact flip out (s)", \.motion.compactFlipOut, step: 0.01, range: 0...10, decimals: 2),
            number("motion.compactFlipLand", "compact flip land (s)", \.motion.compactFlipLand, step: 0.01, range: 0...10, decimals: 2),
            number("motion.takeOutLift", "take out lift (s)", \.motion.takeOutLift, step: 0.01, range: 0...10, decimals: 2),
            number("motion.takeOutHold", "take out hold (s)", \.motion.takeOutHold, step: 0.01, range: 0...10, decimals: 2),
            number("motion.takeOutSettle", "take out settle (s)", \.motion.takeOutSettle, step: 0.01, range: 0...10, decimals: 2),
            number("motion.readyRevealDelay", "ready reveal delay (s)", \.motion.readyRevealDelay, step: 0.01, range: 0...10, decimals: 2),
            number("motion.stageSceneCrossfade", "stage scene crossfade (s)", \.motion.stageSceneCrossfade, step: 0.01, range: 0...10, decimals: 2),
            number("motion.sessionPhaseChange", "session phase change (s)", \.motion.sessionPhaseChange, step: 0.01, range: 0...10, decimals: 2),
            number("motion.progressRailSpring", "progress rail spring (s)", \.motion.progressRailSpring, step: 0.01, range: 0...10, decimals: 2),
            number("motion.resultAppear", "result appear (s)", \.motion.resultAppear, step: 0.01, range: 0...10, decimals: 2),
        ]
    }

    /// Every editable field spec, with cut/doneness groups expanded.
    static var allFields: [NumberFieldSpec] {
        var fields = cookingFields
        for cut in SteakCut.allCases {
            let base = cutKeyPath(cut)
            fields.append(
                number(
                    "\(cut.rawValue).budgetOffset",
                    "Cooking budget offset",
                    base.appending(path: \.cookingBudgetOffset),
                    step: 1, range: -180...180, decimals: 0
                )
            )
            fields.append(
                number(
                    "\(cut.rawValue).recommendedThickness",
                    "Recommended thickness",
                    base.appending(path: \.recommendedThickness),
                    step: 0.5, range: 0.5...10, decimals: 1
                )
            )
        }
        for doneness in Doneness.allCases {
            fields.append(contentsOf: donenessFields(for: doneness))
        }
        fields.append(contentsOf: calibrationFields)
        fields.append(contentsOf: finishingFields)
        for doneness in Doneness.allCases {
            fields.append(
                number(
                    "finishing.doneness.\(doneness.rawValue)",
                    doneness.rawValue,
                    finishingAdjustmentKeyPath(doneness),
                    step: 5, range: 0...300, decimals: 0
                )
            )
        }
        for cut in SteakCut.allCases {
            fields.append(
                number(
                    "\(cut.rawValue).basteMultiplier",
                    "Baste multiplier",
                    cutKeyPath(cut).appending(path: \.basteMultiplier),
                    step: 0.05, range: 0.05...2, decimals: 2
                )
            )
            fields.append(
                optionalNumber(
                    "\(cut.rawValue).fatCapDuration",
                    "Fat cap duration (s)",
                    cutKeyPath(cut).appending(path: \.fatCapDuration),
                    fallback: AppTuning.production.cuts[cut].fatCapDuration ?? 1,
                    step: 5, range: 1...600, decimals: 0
                )
            )
        }
        fields.append(contentsOf: notificationFields)
        fields.append(contentsOf: motionDurationFields)
        fields.append(contentsOf: motionBounceFields)
        return fields
    }

    /// Every editable field, with cut/doneness groups expanded.
    ///
    /// Exposed so a test can assert the Lab covers *all* tunable parameters:
    /// the count must equal the number of leaves in Config/production.yaml.
    static var allFieldIDs: [String] {
        var ids = allFields.map(\.id)
        // The two boolean cut flags are toggles, not numbers.
        for cut in SteakCut.allCases {
            ids.append("\(cut.rawValue).needsFatCap")
        }
        return ids
    }

    static var motionBounceFields: [NumberFieldSpec] {
        [
            number("motion.emphasisBounce", "emphasis bounce", \.motion.emphasisBounce, step: 0.05, range: 0...1, decimals: 2),
            number("motion.actionBounce", "action bounce", \.motion.actionBounce, step: 0.05, range: 0...1, decimals: 2),
            number("motion.progressRailBounce", "progress rail bounce", \.motion.progressRailBounce, step: 0.05, range: 0...1, decimals: 2),
        ]
    }
}
