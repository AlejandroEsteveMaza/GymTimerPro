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
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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
        sectionCard {
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
        sectionCard(alignment: .leading, spacing: 16) {
            Text("progress.chart.workouts.title")
                .font(.headline)

            Chart(selectedSummary.workoutBuckets) { bucket in
                LineMark(
                    x: .value("Bucket", bucket.startDate),
                    y: .value("Workouts", bucket.workouts)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Bucket", bucket.startDate),
                    y: .value("Workouts", bucket.workouts)
                )
                .symbol(.circle)
                .symbolSize(42)
                .foregroundStyle(.blue)
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
        sectionCard {
            Text(store.monthStart, format: .dateTime.month(.wide).year())
                .font(.headline)
            MonthlyCompletionCalendarView(
                monthStart: store.monthStart,
                dayCounts: store.monthlyDayCounts,
                startsOnMonday: store.goal.startsOnMonday,
                activeWeeklyStreak: store.activeWeeklyStreak
            ) { day in
                selectedDay = ProgressSelectedDay(date: day)
            }
        }
    }

    private var activitySection: some View {
        sectionCard {
            Text("progress.section.activity")
                .font(.headline)

            if curatedRecentActivity.isEmpty {
                Text("progress.activity.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    ForEach(curatedRecentActivity) { item in
                        activityCard(item)
                    }
                    if curatedRecentActivity.count == 1 {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 78)
                    }
                }
            }
        }
    }

    private var curatedRecentActivity: [ProgressRecentActivityItem] {
        var rows: [ProgressRecentActivityItem] = []

        if let latestClassification = store.recentCompletions.first(where: { completion in
            guard let name = completion.classificationName else { return false }
            return !name.isEmpty
        }), let classificationName = latestClassification.classificationName {
            rows.append(
                ProgressRecentActivityItem(
                    id: "classification-\(latestClassification.id.uuidString)",
                    title: classificationName,
                    date: latestClassification.completedAt,
                    iconName: "tag.fill",
                    iconColor: .orange
                )
            )
        }

        if let latestRoutine = store.recentCompletions.first {
            rows.append(
                ProgressRecentActivityItem(
                    id: "routine-\(latestRoutine.id.uuidString)",
                    title: latestRoutine.routineName,
                    date: latestRoutine.completedAt,
                    iconName: "figure.strengthtraining.traditional",
                    iconColor: .green
                )
            )
        }

        return Array(rows.prefix(2))
    }

    private var badgesSection: some View {
        sectionCard {
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
        .padding(.bottom, 6)
    }

    private func activityCard(_ item: ProgressRecentActivityItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: item.iconName)
                    .foregroundStyle(item.iconColor)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(item.date, format: .dateTime.day().month().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionCard<Content: View>(
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
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

private struct ProgressRecentActivityItem: Identifiable {
    let id: String
    let title: String
    let date: Date
    let iconName: String
    let iconColor: Color
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
    let activeWeeklyStreak: Int
    let onSelectDay: (Date) -> Void

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale.current
        value.firstWeekday = startsOnMonday ? 2 : 1
        return value
    }

    var body: some View {
        let rows = weekRows()

        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(weekdaySymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                Image(systemName: "flame")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }

            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex]) { item in
                        dayCell(item)
                    }
                    weeklyIndicator(isCurrentWeek: isCurrentWeek(rows[rowIndex]))
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

    private func weekRows() -> [[CalendarDayItem]] {
        let items = calendarDays()
        guard !items.isEmpty else { return [] }
        var rows: [[CalendarDayItem]] = []
        var index = 0
        while index < items.count {
            let end = min(index + 7, items.count)
            rows.append(Array(items[index ..< end]))
            index += 7
        }
        return rows
    }

    private func calendarDays() -> [CalendarDayItem] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let rawCells = leading + dayRange.count
        let rowCount = max(5, Int(ceil(Double(rawCells) / 7.0)))
        let cellCount = rowCount * 7
        guard let firstVisibleDay = calendar.date(byAdding: .day, value: -leading, to: monthInterval.start) else {
            return []
        }

        return (0 ..< cellCount).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: firstVisibleDay) else {
                return nil
            }
            let isCurrentMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
            return CalendarDayItem(id: index, date: date, isCurrentMonth: isCurrentMonth)
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

    @ViewBuilder
    private func dayCell(_ item: CalendarDayItem) -> some View {
        let count = dayCount(for: item.date)
        let hasWorkout = count > 0
        let today = calendar.startOfDay(for: .now)
        let itemDay = calendar.startOfDay(for: item.date)
        let isToday = calendar.isDate(itemDay, inSameDayAs: today)
        let isPast = itemDay < today

        Button {
            if item.isCurrentMonth {
                onSelectDay(item.date)
            }
        } label: {
            Group {
                if item.isCurrentMonth {
                    ZStack {
                        Circle()
                            .fill(dayFillColor(isPast: isPast, isToday: isToday, hasWorkout: hasWorkout))
                        Circle()
                            .stroke(dayBorderColor(isPast: isPast, isToday: isToday, hasWorkout: hasWorkout), lineWidth: 1.5)
                        if count > 0 {
                            Image(systemName: "dumbbell.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                        } else {
                            Text("\(calendar.component(.day, from: item.date))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(width: 20, height: 20)
                } else {
                    Text("\(calendar.component(.day, from: item.date))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(.plain)
        .disabled(!item.isCurrentMonth)
        .accessibilityLabel(accessibilityLabel(for: item.date, count: count))
    }

    @ViewBuilder
    private func weeklyIndicator(isCurrentWeek: Bool) -> some View {
        let showsActiveStreak = isCurrentWeek && activeWeeklyStreak > 0

        ZStack {
            Circle()
                .fill(.white)
            Circle()
                .stroke(showsActiveStreak ? .orange : .gray.opacity(0.5), lineWidth: 1.25)
            if showsActiveStreak {
                Text("\(activeWeeklyStreak)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsActiveStreak {
                Image(systemName: "flame.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.orange)
                    .offset(x: 3, y: -3)
            }
        }
        .frame(width: 20, height: 20)
        .frame(maxWidth: .infinity, minHeight: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                showsActiveStreak
                    ? L10n.format("progress.streak.weeks_format", activeWeeklyStreak)
                    : L10n.tr("progress.calendar.day.empty")
            )
        )
    }

    private func isCurrentWeek(_ week: [CalendarDayItem]) -> Bool {
        let today = calendar.startOfDay(for: .now)
        return week.contains { day in
            calendar.isDate(calendar.startOfDay(for: day.date), inSameDayAs: today)
        }
    }

    private func dayCount(for date: Date) -> Int {
        dayCounts[calendar.startOfDay(for: date), default: 0]
    }

    private func dayBorderColor(isPast: Bool, isToday: Bool, hasWorkout: Bool) -> Color {
        if isToday {
            return .orange
        }
        if isPast, hasWorkout {
            return .orange
        }
        if isPast {
            return .gray.opacity(0.65)
        }
        return .gray.opacity(0.45)
    }

    private func dayFillColor(isPast: Bool, isToday: Bool, hasWorkout: Bool) -> Color {
        if isToday {
            return .clear
        }
        if isPast, hasWorkout {
            return .white
        }
        if isPast {
            return .gray.opacity(0.22)
        }
        return .clear
    }
}

private struct CalendarDayItem: Identifiable {
    let id: Int
    let date: Date
    let isCurrentMonth: Bool
}

#Preview {
    NavigationStack {
        ProgramProgressView()
    }
    .modelContainer(for: [Routine.self, RoutineClassification.self, WorkoutCompletion.self, GoalSettings.self], inMemory: true)
}
