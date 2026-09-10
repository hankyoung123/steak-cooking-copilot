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
                actionTime(context.state)
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
                    actionTime(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.actionTitle)
                        .font(.headline)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                actionTime(context.state)
                    .frame(maxWidth: 54)
            } minimal: {
                Image(systemName: context.state.isUrgent ? "exclamationmark" : "flame.fill")
                    .foregroundStyle(context.state.isUrgent ? .red : .orange)
            }
        }
    }

    @ViewBuilder
    private func actionTime(_ state: SteakActivityAttributes.ContentState) -> some View {
        if let date = state.actionDate, date > .now {
            Text(timerInterval: .now...date, countsDown: true)
                .font(.headline.monospacedDigit())
        } else if state.isUrgent {
            Text("NOW")
                .font(.headline.weight(.black))
                .foregroundStyle(.orange)
        } else {
            // End states (finished/cancelled) carry no countdown.
            EmptyView()
        }
    }
}
