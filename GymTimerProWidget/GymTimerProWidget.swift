import ActivityKit
import SwiftUI
import WidgetKit

@main
struct GymTimerProWidgetBundle: WidgetBundle {
    var body: some Widget {
        GymTimerLiveActivityWidget()
    }
}

struct GymTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymTimerAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Serie \(context.state.currentSet)/\(context.state.totalSets)")
                        .font(.caption.weight(.semibold))
                        .accessibilityLabel("Serie")
                        .accessibilityValue("\(context.state.currentSet) de \(context.state.totalSets)")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityCountdownText(endDate: context.state.endDate)
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(modeLabel(for: context.state.mode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text("\(context.state.currentSet)/\(context.state.totalSets)")
                    .font(.caption2.weight(.semibold))
            } compactTrailing: {
                LiveActivityCountdownText(endDate: context.state.endDate)
                    .font(.caption2.weight(.semibold))
            } minimal: {
                LiveActivityCountdownText(endDate: context.state.endDate)
            }
        }
    }

    private func modeLabel(for mode: GymTimerAttributes.Mode) -> String {
        switch mode {
        case .resting:
            return "Descanso"
        case .training:
            return "Entrenando"
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let state: GymTimerAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Serie \(state.currentSet)/\(state.totalSets)")
                .font(.headline.weight(.semibold))
                .accessibilityLabel("Serie")
                .accessibilityValue("\(state.currentSet) de \(state.totalSets)")

            LiveActivityCountdownText(endDate: state.endDate)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(modeLabel(for: state.mode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func modeLabel(for mode: GymTimerAttributes.Mode) -> String {
        switch mode {
        case .resting:
            return "Descanso"
        case .training:
            return "Entrenando"
        }
    }
}

private struct LiveActivityCountdownText: View {
    let endDate: Date

    var body: some View {
        let now = Date.now
        let end = max(endDate, now)
        Text(timerInterval: now...end, countsDown: true)
            .monospacedDigit()
            .accessibilityLabel("Tiempo restante")
    }
}
