//
//  ProgramProgressView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 05/02/26.
//

import Charts
import SwiftData
import SwiftUI

struct ProgramProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\WorkoutCompletion.completedAt, order: .reverse)]) private var completions: [WorkoutCompletion]
    @Query(sort: [SortDescriptor(\GoalSettings.id, order: .forward)]) private var goalSettings: [GoalSettings]

    @State private var store = ProgramProgressStore()
    @State private var selectedPeriod: ProgressPeriod = .month
    @State private var isPresentingGoalSettings = false
    @State private var selectedDay: ProgressSelectedDay?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summarySection
                goalSection
                streakSection
                periodSection
                chartsSection
                calendarSection
                activitySection
                badgesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("progress.title")
        .task(id: reloadKey) {
            await store.reload(completions: completions, goalSettings: goalSettings.first)
        }
        .sheet(isPresented: $isPresentingGoalSettings) {
            GoalSettingsSheet(
                goalSettings: goalSettings.first,
                onSave: saveGoalSettings
            )
        }
        .sheet(item: $selectedDay) { day in
            NavigationStack {
                List {
                    ForEach(store.completions(on: day.date, startsOnMonday: store.goal.startsOnMonday)) { completion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(completion.routineName)
                                .font(.headline)
                            Text(completion.completedAt, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle(Text(day.date, format: .dateTime.day().month().year()))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var reloadKey: String {
        let firstCompletion = completions.first
        let goal = goalSettings.first
        return [
            "\(completions.count)",
            firstCompletion?.id.uuidString ?? "none",
            "\(firstCompletion?.completedAt.timeIntervalSince1970 ?? 0)",
            "\(goal?.weeklyWorkoutsGoal ?? 0)",
            "\(goal?.weeklyMinutesGoal ?? 0)",
            "\(goal?.startsOnMonday ?? false)"
        ].joined(separator: "|")
    }

    private var selectedSummary: ProgressPeriodSummary {
        store.summary(for: selectedPeriod)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("progress.section.this_week")
                .font(.headline)

            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    summaryCard(
                        titleKey: "progress.summary.workouts",
                        valueText: "\(store.weekSummary.workouts)"
                    )
                    summaryCard(
                        titleKey: "progress.summary.active_days",
                        valueText: "\(store.weekSummary.activeDays)"
                    )
                }
                GridRow {
                    summaryCard(
                        titleKey: "progress.summary.minutes",
                        valueText: "\(store.weekSummary.minutes)"
                    )
                    summaryCard(
                        titleKey: "progress.summary.total_workouts",
                        valueText: "\(store.totalWorkouts)"
                    )
                }
            }
        }
    }

    private func summaryCard(titleKey: String, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(valueText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("progress.goal.weekly")
                    .font(.headline)
                Spacer(minLength: 8)
                Button("progress.goal.edit") {
                    isPresentingGoalSettings = true
                }
                .font(.subheadline.weight(.semibold))
            }

            ProgressView(
                value: min(Double(store.weekSummary.workouts), Double(store.goal.weeklyWorkoutsGoal)),
                total: Double(store.goal.weeklyWorkoutsGoal)
            )
            .tint(.green)

            Text("\(store.weekSummary.workouts)/\(store.goal.weeklyWorkoutsGoal)")
                .font(.subheadline.weight(.semibold))
            Text(store.goalMessage())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                L10n.format(
                    "progress.accessibility.week_goal_format",
                    store.weekSummary.workouts,
                    store.goal.weeklyWorkoutsGoal
                )
            )
        )
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("progress.streak.title")
                .font(.headline)
            Text(L10n.format("progress.streak.weeks_format", store.weeklyStreak))
                .font(.title3.weight(.semibold))
            Text("progress.streak.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress.period.title")
                .font(.headline)
            Picker("progress.period.title", selection: $selectedPeriod) {
                ForEach(ProgressPeriod.allCases) { period in
                    Text(LocalizedStringKey(period.titleKey)).tag(period)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("progress.chart.workouts.title")
                .font(.headline)

            Chart(selectedSummary.workoutBuckets) { bucket in
                BarMark(
                    x: .value("Bucket", bucket.startDate),
                    y: .value("Workouts", bucket.workouts)
                )
                .foregroundStyle(.blue.gradient)
                .cornerRadius(4)
                .accessibilityLabel(Text(bucket.startDate, format: .dateTime.day().month()))
                .accessibilityValue(Text(L10n.format("progress.chart.workouts.accessibility_value_format", bucket.workouts)))
            }
            .frame(height: 180)
            .chartYAxisLabel(L10n.tr("progress.chart.axis.workouts"), position: .leading)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6))
            }

            if selectedSummary.hasDurationData {
                Text("progress.chart.minutes.title")
                    .font(.headline)
                Chart(selectedSummary.workoutBuckets) { bucket in
                    BarMark(
                        x: .value("Bucket", bucket.startDate),
                        y: .value("Minutes", bucket.minutes)
                    )
                    .foregroundStyle(.green.gradient)
                    .cornerRadius(4)
                    .accessibilityLabel(Text(bucket.startDate, format: .dateTime.day().month()))
                    .accessibilityValue(Text(L10n.format("progress.chart.minutes.accessibility_value_format", bucket.minutes)))
                }
                .frame(height: 160)
                .chartYAxisLabel(L10n.tr("progress.chart.axis.minutes"), position: .leading)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6))
                }
            }

            if let routine = selectedSummary.mostRepeatedRoutineName {
                LabeledContent("progress.summary.most_repeated", value: routine)
                    .font(.subheadline)
            }
            if let classification = selectedSummary.topClassificationName {
                LabeledContent("progress.summary.top_classification", value: classification)
                    .font(.subheadline)
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("progress.calendar.title")
                .font(.headline)
            MonthlyCompletionCalendarView(
                monthStart: store.monthStart,
                dayCounts: store.monthlyDayCounts,
                startsOnMonday: store.goal.startsOnMonday
            ) { day in
                selectedDay = ProgressSelectedDay(date: day)
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("progress.section.activity")
                .font(.headline)

            if store.recentCompletions.isEmpty {
                Text("progress.activity.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(store.recentCompletions.prefix(12))) { completion in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.routineName)
                                .font(.subheadline.weight(.semibold))
                            Text(completion.completedAt, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("progress.section.badges")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(store.badges) { badge in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: badge.isUnlocked ? "medal.fill" : "lock.fill")
                                .foregroundStyle(badge.isUnlocked ? .yellow : .secondary)
                            Spacer(minLength: 0)
                        }
                        Text(LocalizedStringKey(badge.titleKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(LocalizedStringKey(badge.subtitleKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                    .opacity(badge.isUnlocked ? 1 : 0.7)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func saveGoalSettings(
        weeklyWorkoutsGoal: Int,
        weeklyMinutesGoal: Int,
        startsOnMonday: Bool
    ) {
        if let current = goalSettings.first {
            current.weeklyWorkoutsGoal = max(1, weeklyWorkoutsGoal)
            current.weeklyMinutesGoal = max(0, weeklyMinutesGoal)
            current.startsOnMonday = startsOnMonday
        } else {
            let newSettings = GoalSettings(
                weeklyWorkoutsGoal: weeklyWorkoutsGoal,
                weeklyMinutesGoal: weeklyMinutesGoal,
                startsOnMonday: startsOnMonday
            )
            modelContext.insert(newSettings)
        }
        try? modelContext.save()
    }
}

private struct ProgressSelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

private struct GoalSettingsSheet: View {
    let goalSettings: GoalSettings?
    let onSave: (Int, Int, Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var weeklyWorkoutsGoal: Int
    @State private var weeklyMinutesGoal: Int
    @State private var startsOnMonday: Bool

    init(
        goalSettings: GoalSettings?,
        onSave: @escaping (Int, Int, Bool) -> Void
    ) {
        self.goalSettings = goalSettings
        self.onSave = onSave
        _weeklyWorkoutsGoal = State(initialValue: goalSettings?.weeklyWorkoutsGoal ?? 3)
        _weeklyMinutesGoal = State(initialValue: goalSettings?.weeklyMinutesGoal ?? 120)
        _startsOnMonday = State(initialValue: goalSettings?.startsOnMonday ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Stepper(
                    value: $weeklyWorkoutsGoal,
                    in: 1 ... 14
                ) {
                    LabeledContent("progress.goal.workouts_per_week") {
                        Text("\(weeklyWorkoutsGoal)")
                    }
                }

                Stepper(
                    value: $weeklyMinutesGoal,
                    in: 0 ... 1200,
                    step: 10
                ) {
                    LabeledContent("progress.goal.minutes_per_week") {
                        Text("\(weeklyMinutesGoal)")
                    }
                }

                Toggle("progress.goal.starts_on_monday", isOn: $startsOnMonday)
            }
            .navigationTitle("progress.goal.settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("routines.save") {
                        onSave(weeklyWorkoutsGoal, weeklyMinutesGoal, startsOnMonday)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct MonthlyCompletionCalendarView: View {
    let monthStart: Date
    let dayCounts: [Date: Int]
    let startsOnMonday: Bool
    let onSelectDay: (Date) -> Void

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale.current
        value.firstWeekday = startsOnMonday ? 2 : 1
        return value
    }

    var body: some View {
        let days = calendarDays()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(weekdaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            ForEach(days, id: \.id) { item in
                if let date = item.date {
                    let count = dayCounts[calendar.startOfDay(for: date), default: 0]
                    Button {
                        onSelectDay(date)
                    } label: {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(count > 0 ? .white : .primary)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(
                                Circle()
                                    .fill(count > 0 ? Color.green : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: date, count: count))
                } else {
                    Color.clear
                        .frame(height: 30)
                }
            }
        }
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let start = max(0, calendar.firstWeekday - 1)
        return Array(symbols[start...] + symbols[..<start])
    }

    private func calendarDays() -> [CalendarDayItem] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let total = leading + dayRange.count
        let trailing = (7 - (total % 7)) % 7
        let cellCount = total + trailing

        return (0 ..< cellCount).map { index in
            let dayOffset = index - leading
            guard dayOffset >= 0, dayOffset < dayRange.count else {
                return CalendarDayItem(id: index, date: nil)
            }
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start)
            return CalendarDayItem(id: index, date: date)
        }
    }

    private func accessibilityLabel(for date: Date, count: Int) -> Text {
        if count > 0 {
            return Text(L10n.format("progress.calendar.day.completed_format", count))
                + Text(" ")
                + Text(date, format: .dateTime.day().month().year())
        }
        return Text(L10n.tr("progress.calendar.day.empty"))
            + Text(" ")
            + Text(date, format: .dateTime.day().month().year())
    }
}

private struct CalendarDayItem: Identifiable {
    let id: Int
    let date: Date?
}

#Preview {
    NavigationStack {
        ProgramProgressView()
    }
    .modelContainer(for: [Routine.self, RoutineClassification.self, WorkoutCompletion.self, GoalSettings.self], inMemory: true)
}
