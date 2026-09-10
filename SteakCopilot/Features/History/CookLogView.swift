import SwiftUI

struct CookLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    let records: [FeedbackRecord]
    /// Target temperatures come from production tuning, so the log shows the
    /// same values the cook actually targeted.
    let tuning: AppTuning

    var body: some View {
        ZStack {
            EditorialCanvas(dark: true)

            ScrollView {
                VStack(spacing: 0) {
                    header

                    Text("Your Cook Log")
                        .editorialDisplayStyle(size: 30, color: theme.porcelain.opacity(0.9))
                        .accessibilityIdentifier("history.title")
                        .padding(.top, 15)
                        .padding(.bottom, 24)

                    LazyVStack(spacing: 10) {
                        if records.isEmpty {
                            emptyState
                        } else {
                            ForEach(records) { record in
                                CookLogRow(record: record, tuning: tuning)
                            }
                        }
                    }

                    Text("View All Logs")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.14), lineWidth: 0.8)
                        }
                        .padding(.top, 22)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button("Close", systemImage: "chevron.left") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .light))
                .accessibilityIdentifier("history.close")
            Spacer()
        }
        .frame(height: 44)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(theme.butter)
            Text("No cooks logged yet")
                .font(.system(size: 20, weight: .regular, design: .serif))
            Text("Your completed steaks will appear here.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.43))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

private struct CookLogRow: View {
    @Environment(AppTheme.self) private var theme
    let record: FeedbackRecord
    let tuning: AppTuning

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(record.configuration.cut.title)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(theme.porcelain.opacity(0.9))
                Text(record.configuration.doneness.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.46))
                HStack {
                    Text(
                        String(
                            format: "%.0f°C",
                            tuning.doneness[
                                record.configuration.doneness
                            ].targetTemperatureC
                        )
                    )
                        .font(.system(size: 13, weight: .regular, design: .serif))
                    Spacer()
                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.38))
                }
            }

            Image("ResultHeroCutout")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .padding(4)
                .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(.white.opacity(0.09), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
    }
}
