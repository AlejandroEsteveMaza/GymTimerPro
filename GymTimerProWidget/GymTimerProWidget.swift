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
            let accent = modeAccent(for: context.state.mode)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: modeSymbolName(for: context.state.mode))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                        Text(modeLabel(for: context.state.mode))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveActivityCountdownText(endDate: context.state.endDate)
                        .font(.caption.weight(.semibold))
                        .padding(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Serie \(context.state.currentSet)/\(context.state.totalSets)")
                                .font(.caption.weight(.semibold))
                                .accessibilityLabel("Serie")
                                .accessibilityValue("\(context.state.currentSet) de \(context.state.totalSets)")
                            Spacer(minLength: 0)
                            Text("GymTimer")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        ProgressView(value: setProgress(currentSet: context.state.currentSet, totalSets: context.state.totalSets))
                            .tint(accent)
                            .accessibilityLabel("Progreso de series")
                            .accessibilityValue("\(context.state.currentSet) de \(context.state.totalSets)")
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: modeSymbolName(for: context.state.mode))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("\(context.state.currentSet)/\(context.state.totalSets)")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
            } compactTrailing: {
                LiveActivityCountdownText(endDate: context.state.endDate)
                    .font(.caption2.weight(.semibold))
            } minimal: {
                LiveActivityCountdownText(endDate: context.state.endDate)
                    .font(.caption2.weight(.semibold))
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

    private func modeAccent(for mode: GymTimerAttributes.Mode) -> Color {
        switch mode {
        case .resting:
            return Color.orange
        case .training:
            return Color.orange
        }
    }

    private func modeSymbolName(for mode: GymTimerAttributes.Mode) -> String {
        "timer"
    }

    private func setProgress(currentSet: Int, totalSets: Int) -> Double {
        guard totalSets > 0 else { return 0 }
        return min(max(Double(currentSet) / Double(totalSets), 0), 1)
    }
}

private struct LiveActivityLockScreenView: View {
    let state: GymTimerAttributes.ContentState

    var body: some View {
        let accent = modeAccent(for: state.mode)

        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: modeSymbolName(for: state.mode))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(accent)

                    Text(modeLabel(for: state.mode))
                        .font(.headline.weight(.semibold))
                }

                Text("Serie \(state.currentSet)/\(state.totalSets)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Serie")
                    .accessibilityValue("\(state.currentSet) de \(state.totalSets)")

                ProgressView(value: setProgress(currentSet: state.currentSet, totalSets: state.totalSets))
                    .tint(accent)
                    .accessibilityLabel("Progreso de series")
                    .accessibilityValue("\(state.currentSet) de \(state.totalSets)")
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Restante")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LiveActivityCountdownText(endDate: state.endDate)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 12)
    }

    private func modeLabel(for mode: GymTimerAttributes.Mode) -> String {
        switch mode {
        case .resting:
            return "Descanso"
        case .training:
            return "Entrenando"
        }
    }

    private func modeAccent(for mode: GymTimerAttributes.Mode) -> Color {
        switch mode {
        case .resting:
            return Color.orange
        case .training:
            return Color.orange
        }
    }

    private func modeSymbolName(for mode: GymTimerAttributes.Mode) -> String {
        "timer"
    }

    private func setProgress(currentSet: Int, totalSets: Int) -> Double {
        guard totalSets > 0 else { return 0 }
        return min(max(Double(currentSet) / Double(totalSets), 0), 1)
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
