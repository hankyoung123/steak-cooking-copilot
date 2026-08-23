import SwiftUI

struct CookLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    let records: [FeedbackRecord]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if records.isEmpty {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 38, weight: .light))
                                .foregroundStyle(theme.butter)
                            Text("No cooks logged yet")
                                .font(.title3.weight(.semibold))
                            Text("Your completed steaks will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xl)
                    } else {
                        ForEach(records) { record in
                            CookLogRow(record: record)
                            Divider().opacity(0.5)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
            }
            .background(theme.porcelain)
            .navigationTitle("Cook Log")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("history.close")
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct CookLogRow: View {
    @Environment(AppTheme.self) private var theme
    let record: FeedbackRecord

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(record.configuration.doneness.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 60)

            VStack(alignment: .leading, spacing: 5) {
                Text(record.configuration.cut.title)
                    .font(.headline)
                Text(
                    String(
                        format: String(localized: "%@ · %.1f cm"),
                        record.configuration.doneness.title,
                        record.configuration.thicknessCM
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: record.doneness == .perfect ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(record.doneness == .perfect ? theme.butter : Color.secondary)
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
