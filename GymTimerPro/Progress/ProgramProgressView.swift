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
    @Query(sort: [SortDescriptor(\WorkoutCompletion.completedAt, order: .reverse)]) private var completions: [WorkoutCompletion]

    @State private var store = ProgramProgressStore()
    @State private var selectedPeriod: ProgressPeriod = .month
    @State private var selectedDay: ProgressSelectedDay?
    private let chartCalendar = Calendar.autoupdatingCurrent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
            await store.reload(completions: completions)
        }
        .sheet(item: $selectedDay) { day in
            NavigationStack {
                List {
                    ForEach(store.completions(on: day.date)) { completion in
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
        return [
            "\(completions.count)",
            firstCompletion?.id.uuidString ?? "none",
            "\(firstCompletion?.completedAt.timeIntervalSince1970 ?? 0)"
        ].joined(separator: "|")
    }

    private var selectedSummary: ProgressPeriodSummary {
        store.summary(for: selectedPeriod)
    }

    private var chartsSection: some View {
        sectionCard(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("progress.chart.workouts.title")
                    .font(.headline)
                Spacer(minLength: 8)
                Picker("progress.period.title", selection: $selectedPeriod) {
                    ForEach(ProgressPeriod.allCases) { period in
                        Text(LocalizedStringKey(period.titleKey)).tag(period)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(.subheadline.weight(.semibold))
                .accessibilityLabel(Text("progress.period.title"))
            }

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
                if selectedPeriod == .quarter {
                    AxisMarks(values: quarterXAxisValues) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(xAxisLabel(for: date))
                            }
                        }
                    }
                } else {
                    AxisMarks(values: xAxisValues) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(xAxisLabel(for: date))
                            }
                        }
                    }
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

    private var xAxisValues: AxisMarkValues {
        switch selectedPeriod {
        case .week, .fortnight:
            return .stride(by: .day, count: 2)
        case .month:
            return .stride(by: .weekOfYear)
        case .quarter:
            return .stride(by: .month)
        case .year:
            return .stride(by: .month)
        }
    }

    private var quarterXAxisValues: [Date] {
        let bucketDates = selectedSummary.workoutBuckets.map(\.startDate)
        guard let first = bucketDates.first, let last = bucketDates.last,
              let currentMonthStart = chartCalendar.dateInterval(of: .month, for: .now)?.start
        else {
            return []
        }

        let start = chartCalendar.startOfDay(for: first)
        let end = chartCalendar.date(byAdding: .weekOfYear, value: 1, to: last) ?? last
        let candidateMonths = [
            chartCalendar.date(byAdding: .month, value: -2, to: currentMonthStart),
            chartCalendar.date(byAdding: .month, value: -1, to: currentMonthStart),
            currentMonthStart
        ].compactMap { $0 }

        let inRange = candidateMonths.filter { $0 >= start && $0 < end }
        if !inRange.isEmpty {
            return inRange
        }

        let monthStarts = Set(
            bucketDates.compactMap { chartCalendar.dateInterval(of: .month, for: $0)?.start }
        )
        return monthStarts.sorted()
    }

    private func xAxisLabel(for date: Date) -> String {
        switch selectedPeriod {
        case .week, .fortnight:
            return date.formatted(.dateTime.day())
        case .month:
            return "W\(chartCalendar.component(.weekOfYear, from: date))"
        case .quarter:
            return date.formatted(.dateTime.month(.abbreviated))
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        }
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

private struct MonthlyCompletionCalendarView: View {
    let monthStart: Date
    let dayCounts: [Date: Int]
    let activeWeeklyStreak: Int
    let onSelectDay: (Date) -> Void

    private var calendar: Calendar {
        Calendar.autoupdatingCurrent
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
        let canOpenDetails = item.isCurrentMonth && hasWorkout

        Button {
            if canOpenDetails {
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
                                .foregroundStyle(.white)
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
        .disabled(!canOpenDetails)
        .accessibilityLabel(accessibilityLabel(for: item.date, count: count))
    }

    @ViewBuilder
    private func weeklyIndicator(isCurrentWeek: Bool) -> some View {
        let showsActiveStreak = isCurrentWeek && activeWeeklyStreak > 0

        Group {
            if showsActiveStreak {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(activeWeeklyStreak)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.orange)
            } else {
                ZStack {
                    Circle()
                        .fill(.white)
                    Circle()
                        .stroke(.gray.opacity(0.5), lineWidth: 1.25)
                }
                .frame(width: 20, height: 20)
            }
        }
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
        if hasWorkout {
            return .blue
        }
        if isToday {
            return .clear
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
    .modelContainer(for: [Routine.self, RoutineClassification.self, WorkoutCompletion.self], inMemory: true)
}
