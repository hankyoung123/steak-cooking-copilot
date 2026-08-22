import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SteakCopilotWidgets: WidgetBundle {
    var body: some Widget {
        SteakLiveActivityWidget()
    }
}

struct SteakLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SteakActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.phaseTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(context.state.actionTitle)
                        .font(.headline)
                }
                Spacer()
                actionTime(context.state.actionDate)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.10, green: 0.085, blue: 0.07))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.phaseTitle, systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    actionTime(context.state.actionDate)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.actionTitle)
                        .font(.headline)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                actionTime(context.state.actionDate)
                    .frame(maxWidth: 54)
            } minimal: {
                Image(systemName: context.state.isUrgent ? "exclamationmark" : "flame.fill")
                    .foregroundStyle(context.state.isUrgent ? .red : .orange)
            }
        }
    }

    @ViewBuilder
    private func actionTime(_ date: Date?) -> some View {
        if let date, date > .now {
            Text(timerInterval: .now...date, countsDown: true)
                .font(.headline.monospacedDigit())
        } else {
            Text("NOW")
                .font(.headline.weight(.black))
                .foregroundStyle(.orange)
        }
    }
}
