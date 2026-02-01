//
//  ContentView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 24/12/25.
//

import SwiftUI
import Combine
import SwiftData
import UIKit
import AudioToolbox

struct ContentView: View {
    @AppStorage("training.total_sets") private var totalSeries: Int = 4
    @AppStorage("training.rest_seconds") private var tiempoDescanso: Int = 90
    @AppStorage("training.current_set") private var serieActual: Int = 1
    @AppStorage("training.completed") private var completado: Bool = false
    @AppStorage("training.applied_routine_name") private var appliedRoutineNameStorage: String = ""
    @AppStorage("training.applied_routine_reps") private var appliedRoutineRepsStorage: Int = 0
    @State private var stepperControlSize: CGSize = Layout.defaultStepperControlSize
    @StateObject private var restTimer = RestTimerModel()
    @StateObject private var liveActivityManager = LiveActivityManager()
    @StateObject private var usageLimiter = DailyUsageLimiter(dailyLimit: 19)
    @State private var isPresentingPaywall = false
    @State private var showNotificationPreview = false
    @State private var uiTestOverridesApplied = false
    @State private var isPresentingRoutinePicker = false
    private let restFinishedSoundID: SystemSoundID = 1322

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var routineSelectionStore: RoutineSelectionStore

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Layout.sectionSpacing) {
                    configurationSection
                    progressSection
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Layout.topPadding)
                .padding(.bottom, Layout.scrollBottomPadding)
            }
            .accessibilityIdentifier("homeScreen")

            if showNotificationPreview {
                notificationPreviewOverlay
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controlsSection
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            applyUITestOverridesIfNeeded()
            applyRoutineSelection(routineSelectionStore.selection)
            liveActivityManager.requestNotificationAuthorizationIfNeeded()
            usageLimiter.refresh(now: .now)
            restTimer.tick(now: .now)
            if restTimer.didFinish {
                handleRestFinished()
            } else {
                restoreLiveActivityIfNeeded()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            restTimer.persist()
        }
        .onChange(of: totalSeries) { _, newValue in
            if self.serieActual > newValue {
                self.serieActual = newValue
            }
            if self.serieActual < 1 {
                self.serieActual = 1
            }
        }
        .onChange(of: routineSelectionStore.selection) { _, selection in
            applyRoutineSelection(selection)
        }
        .onChange(of: scenePhase) { _, newPhase in
            restTimer.handleScenePhase(newPhase)
            if newPhase == .active {
                usageLimiter.refresh(now: .now)
            }
            if newPhase == .active, restTimer.didFinish {
                handleRestFinished()
            }
        }
        .onChange(of: restTimer.endDate) { _, newDate in
            guard let newDate, isResting else { return }
            updateLiveActivity(endDate: newDate, mode: .resting)
        }
        .onChange(of: restTimer.didFinish) { _, finished in
            if finished, scenePhase == .active {
                handleRestFinished()
            }
        }
        .onChange(of: restTimer.isRunning) { _, running in
            if !running {
                liveActivityManager.end()
            }
        }
        .sheet(isPresented: $isPresentingPaywall) {
            PaywallView(
                dailyLimit: usageLimiter.status.dailyLimit,
                consumedToday: usageLimiter.status.consumedToday,
                accentColor: Theme.primaryButton
            )
            .environmentObject(purchaseManager)
        }
        .sheet(isPresented: $isPresentingRoutinePicker) {
            NavigationStack {
                RoutinePickerView { routine in
                    routineSelectionStore.apply(routine)
                }
            }
        }
    }

    private var configurationSection: some View {
        SectionCard(
            titleKey: "section.configuration.title",
            systemImage: "slider.horizontal.3",
            trailing: {
                if purchaseManager.isPro {
                    proStatusIcon
                }
            }
        ) {
            VStack(spacing: Layout.rowSpacing) {
                if purchaseManager.isPro {
                    routineApplyRow
                    Divider()
                        .foregroundStyle(Theme.divider)
                }
                configWheelRow(
                    titleKey: "config.total_sets.title",
                    icon: "square.stack.3d.up",
                    value: $totalSeries,
                    range: 1...10,
                    valueEditorIdentifier: "totalSetsValueButton",
                    editorPickerIdentifier: "totalSetsPicker",
                    accessibilityValue: L10n.format("accessibility.total_sets_value_format", totalSeries)
                )
                Divider()
                    .foregroundStyle(Theme.divider)
                configWheelRow(
                    titleKey: "config.rest_seconds.title",
                    icon: "timer",
                    value: $tiempoDescanso,
                    range: 15...300,
                    step: 15,
                    accessibilityValue: L10n.format("accessibility.rest_seconds_value_format", tiempoDescanso)
                )
                if !purchaseManager.isPro {
                    Divider()
                        .foregroundStyle(Theme.divider)
                    proRow
                }
            }
        }
        .disabled(isTimerActive || completado)
        .opacity(isTimerActive || completado ? 0.55 : 1.0)
        .tint(Theme.primaryButton)
        .overlay(alignment: .topTrailing) {
            StepperSizeReader(size: $stepperControlSize)
        }
    }

    private var progressSection: some View {
        SectionCard(
            titleKey: "section.progress.title",
            systemImage: "chart.line.uptrend.xyaxis",
            trailing: {
                ResetIconButton(action: resetWorkout, isEnabled: canReset)
            }
        ) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let now = Date.now
                let tickID = Int(now.timeIntervalSince1970)

                progressContent(now: now)
                    .task(id: tickID) {
                        restTimer.tick(now: now)
                    }
            }
        }
        .animation(.snappy, value: isResting)
        .animation(.snappy, value: completado)
    }

    private var controlsSection: some View {
        VStack(spacing: Layout.buttonSpacing) {
            Button(action: startRest) {
                Label("button.start_rest.title", systemImage: "pause.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle(height: Layout.primaryButtonHeight))
            .accessibilityIdentifier("startRestButton")
            .disabled(isResting || completado)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.controlsVerticalPadding)
        .padding(.bottom, Layout.controlsVerticalPadding)
        .background(Theme.controlsBackground)
        .overlay(alignment: .top) {
            Divider()
                .foregroundStyle(Theme.divider)
        }
        .shadow(color: Theme.cardShadow, radius: 12, x: 0, y: -6)
    }

    private func configWheelRow(
        titleKey: String,
        icon: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        valueEditorIdentifier: String? = nil,
        editorPickerIdentifier: String? = nil,
        accessibilityValue: String
    ) -> some View {
        let localizedTitle = L10n.tr(titleKey)
        return HStack(spacing: 12) {
            ConfigRow(icon: icon, titleKey: titleKey) {
                ConfigValueEditorButton(
                    titleKey: titleKey,
                    value: value,
                    range: range,
                    step: step,
                    accessibilityIdentifier: valueEditorIdentifier,
                    editorPickerIdentifier: editorPickerIdentifier
                )
            }
                .layoutPriority(1)
            HorizontalWheelStepper(
                value: value,
                range: range,
                step: step,
                controlSize: stepperControlSize,
                accessibilityLabel: localizedTitle,
                accessibilityValue: accessibilityValue
            )
        }
        .frame(minHeight: Layout.minTapHeight)
    }

    private var routineApplyRow: some View {
        Button {
            if purchaseManager.isPro {
                isPresentingRoutinePicker = true
            } else {
                isPresentingPaywall = true
            }
        } label: {
            ConfigRow(icon: "list.bullet.rectangle", titleKey: "training.routine.title") {
                HStack(spacing: 6) {
                    Text(appliedRoutineName ?? L10n.tr("training.routine.select"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(appliedRoutineName == nil ? Theme.textSecondary : Theme.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("training.routine.title"))
        .accessibilityValue(Text(appliedRoutineName ?? L10n.tr("training.routine.select")))
    }

    @ViewBuilder
    private func progressContent(now: Date) -> some View {
        if completado {
            completionView
                .transition(.opacity.combined(with: .scale))
        } else {
            VStack(alignment: .leading, spacing: Layout.metricSpacing) {
                HStack(spacing: Layout.metricSpacing) {
                    MetricView(titleKey: "metric.set.title", value: "\(serieActual) / \(totalSeries)")
                    if purchaseManager.isPro, let reps = appliedRoutineReps {
                        MetricView(titleKey: "routines.field.reps", value: "\(reps)")
                    }
                }

                HStack(spacing: 12) {
                    Text("label.state")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    statusBadge
                    Spacer(minLength: 0)
                }

                if isResting {
                    restTimerView(remainingSeconds: restTimer.remainingSeconds(now: now))
                }
            }
        }
    }

    private var statusBadge: some View {
        let status = statusStyle
        return Label(LocalizedStringKey(status.textKey), systemImage: status.icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.15), in: Capsule())
            .foregroundStyle(status.color)
            .symbolRenderingMode(.hierarchical)
    }

    private var statusStyle: (textKey: String, icon: String, color: Color) {
        if isResting {
            return ("status.resting", "hourglass", Theme.resting)
        }
        return ("status.training", "figure.walk", Theme.training)
    }

    private func restTimerView(remainingSeconds: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("label.rest_time", systemImage: "timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .symbolRenderingMode(.hierarchical)

            Text("\(remainingSeconds)")
                .font(.system(size: Layout.timerFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.resting)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.9), value: remainingSeconds)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.timerPadding)
        .background(Theme.timerBackground, in: RoundedRectangle(cornerRadius: Layout.metricCornerRadius, style: .continuous))
        .accessibilityIdentifier("restTimerView")
    }

    private var completionView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.completed)
                .symbolRenderingMode(.hierarchical)
            Text("workout.completed")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var isTimerActive: Bool {
        restTimer.isRunning
    }

    private var isResting: Bool {
        restTimer.isRunning
    }

    private var canReset: Bool {
        completado || isResting || serieActual > 1
    }

    private func startRest() {
        guard !isResting, !completado else { return }

        if serieActual >= totalSeries {
            completeWorkout()
            return
        }

        let now = Date.now
        guard usageLimiter.canConsume(now: now, isPro: purchaseManager.isPro) else {
            isPresentingPaywall = true
            return
        }
        usageLimiter.consume(now: now, isPro: purchaseManager.isPro)

        withAnimation(.snappy) {
            serieActual += 1
        }

        restTimer.start(duration: TimeInterval(tiempoDescanso))

        if let endDate = restTimer.endDate {
            updateLiveActivity(endDate: endDate, mode: .resting)
        }
    }

    private func handleRestFinished() {
        restTimer.acknowledgeFinish()
        liveActivityManager.end()
        liveActivityManager.cancelEndNotification()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(restFinishedSoundID)
    }

    private func completeWorkout() {
        restTimer.reset()
        liveActivityManager.end()
        liveActivityManager.cancelEndNotification()

        withAnimation(.snappy) {
            completado = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.completado {
                self.resetWorkout()
            }
        }
    }

    private func resetWorkout() {
        restTimer.reset()
        liveActivityManager.end()
        liveActivityManager.cancelEndNotification()

        withAnimation(.snappy) {
            serieActual = 1
            completado = false
        }
    }

    private func applyRoutineSelection(_ selection: RoutineSelectionStore.Selection?) {
        guard let selection else {
            appliedRoutineName = nil
            appliedRoutineReps = nil
            return
        }
        let isAlreadyApplied = appliedRoutineName == selection.name
            && appliedRoutineReps == selection.reps
            && totalSeries == selection.totalSets
            && tiempoDescanso == selection.restSeconds
        guard !isAlreadyApplied else { return }
        resetWorkout()
        totalSeries = selection.totalSets
        tiempoDescanso = selection.restSeconds
        appliedRoutineName = selection.name
        appliedRoutineReps = selection.reps
    }

    private var appliedRoutineName: String? {
        get { appliedRoutineNameStorage.isEmpty ? nil : appliedRoutineNameStorage }
        nonmutating set { appliedRoutineNameStorage = newValue ?? "" }
    }

    private var appliedRoutineReps: Int? {
        get { appliedRoutineRepsStorage == 0 ? nil : appliedRoutineRepsStorage }
        nonmutating set { appliedRoutineRepsStorage = newValue ?? 0 }
    }


    private func restoreLiveActivityIfNeeded() {
        guard restTimer.isRunning, let endDate = restTimer.endDate else { return }
        if endDate <= .now {
            restTimer.tick(now: .now)
            if restTimer.didFinish {
                handleRestFinished()
            }
            return
        }
        updateLiveActivity(endDate: endDate, mode: .resting)
    }

    private func updateLiveActivity(endDate: Date, mode: GymTimerAttributes.Mode) {
        liveActivityManager.startOrUpdate(
            currentSet: serieActual,
            totalSets: totalSeries,
            endDate: endDate,
            mode: mode
        )
        if mode == .resting {
            liveActivityManager.scheduleEndNotification(
                endDate: endDate,
                currentSet: serieActual,
                totalSets: totalSeries
            )
        }
    }

    private var proRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.iconTint)
                .frame(width: 28, height: 28)
                .background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("pro.status.free")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(L10n.format("pro.usage_today_format", usageLimiter.status.consumedToday, usageLimiter.status.dailyLimit))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Button("pro.button.upgrade") {
                isPresentingPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .tint(Theme.primaryButton)
            .bold()
        }
        .frame(minHeight: Layout.minTapHeight)
    }

    private var proStatusIcon: some View {
        HStack(spacing: 6) {
            Text("pro.status.pro")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.completed)
                .frame(width: 24, height: 24)
                .background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }

    private var isUITesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-ui_testing") || args.contains("ui-testing")
    }

    private func applyUITestOverridesIfNeeded() {
        guard isUITesting, !uiTestOverridesApplied else { return }
        uiTestOverridesApplied = true
        let env = ProcessInfo.processInfo.environment

        if let setsValue = env["UITEST_TOTAL_SETS"], let sets = Int(setsValue) {
            totalSeries = sets
            if serieActual > sets {
                serieActual = sets
            }
        }
        if let restValue = env["UITEST_REST_SECONDS"], let rest = Int(restValue) {
            tiempoDescanso = rest
        }
        if let currentValue = env["UITEST_CURRENT_SET"], let current = Int(currentValue) {
            serieActual = current
        }
        if env["UITEST_SHOW_NOTIFICATION_PREVIEW"] == "1" {
            showNotificationPreview = true
        }
    }

    private var notificationPreviewOverlay: some View {
        VStack(spacing: 12) {
            notificationPreviewBanner
            liveActivityPreviewCard
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("notificationPreview")
    }

    private var notificationPreviewBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.resting)
                .frame(width: 28, height: 28)
                .background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("notification.rest_finished.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(L10n.format("notification.rest_finished.body_format", serieActual, totalSeries))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 0)

            Text("common.now")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 12, x: 0, y: 6)
    }

    private var liveActivityPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("live_activity.mode.resting", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.resting)
                Spacer(minLength: 0)
                Text(previewTimeString)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }

            Text(L10n.format("live_activity.set_progress_expanded_format", serieActual, totalSeries))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            ProgressView(value: previewSetProgress)
                .tint(Theme.resting)
        }
        .padding(16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 12, x: 0, y: 6)
    }

    private var previewSetProgress: Double {
        guard totalSeries > 0 else { return 0 }
        return min(max(Double(serieActual) / Double(totalSeries), 0), 1)
    }

    private var previewTimeString: String {
        formatTime(max(1, tiempoDescanso))
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remaining = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

// Countdown state is derived from endDate; remaining is stored for paused state and persistence.
private final class RestTimerModel: ObservableObject {
    @Published private(set) var isRunning: Bool
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var endDate: Date?
    @Published var didFinish: Bool = false

    private let storage: UserDefaults
    private var timerCancellable: AnyCancellable?

    private enum Keys {
        static let endDate = "restTimer.endDate"
        static let isRunning = "restTimer.isRunning"
        static let remaining = "restTimer.remaining"
    }

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        self.isRunning = storage.bool(forKey: Keys.isRunning)
        self.remaining = storage.double(forKey: Keys.remaining)
        self.endDate = storage.object(forKey: Keys.endDate) as? Date
        reconcile(now: .now)
        if isRunning {
            startTimerLoop()
        }
    }

    var remainingSeconds: Int {
        remainingSeconds(now: .now)
    }

    func remainingSeconds(now: Date) -> Int {
        let interval: TimeInterval
        if isRunning, let endDate {
            interval = max(0, endDate.timeIntervalSince(now))
        } else {
            interval = remaining
        }
        return max(0, Int(interval.rounded(.up)))
    }

    func start(duration: TimeInterval, now: Date = .now) {
        remaining = max(0, duration)
        endDate = now.addingTimeInterval(remaining)
        isRunning = remaining > 0
        didFinish = false
        startTimerLoop()
        persist()
    }

    func pause(now: Date = .now) {
        guard isRunning, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSince(now))
        self.endDate = nil
        isRunning = false
        stopTimerLoop()
        persist()
    }

    func resume(now: Date = .now) {
        guard !isRunning, remaining > 0 else { return }
        endDate = now.addingTimeInterval(remaining)
        isRunning = true
        startTimerLoop()
        persist()
    }

    func tick(now: Date) {
        guard isRunning, let endDate else { return }
        let newRemaining = max(0, endDate.timeIntervalSince(now))
        if newRemaining != remaining {
            remaining = newRemaining
        }
        if newRemaining <= 0 {
            finish()
        }
    }

    func reset() {
        isRunning = false
        endDate = nil
        remaining = 0
        didFinish = false
        stopTimerLoop()
        persist()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            tick(now: .now)
        case .inactive, .background:
            tick(now: .now)
            persist()
        @unknown default:
            persist()
        }
    }

    func persist() {
        storage.set(isRunning, forKey: Keys.isRunning)
        storage.set(remaining, forKey: Keys.remaining)
        if let endDate {
            storage.set(endDate, forKey: Keys.endDate)
        } else {
            storage.removeObject(forKey: Keys.endDate)
        }
    }

    func acknowledgeFinish() {
        didFinish = false
    }

    private func reconcile(now: Date) {
        guard isRunning else {
            if endDate != nil {
                endDate = nil
                persist()
            }
            return
        }
        guard let endDate else {
            isRunning = false
            remaining = 0
            persist()
            return
        }
        let newRemaining = max(0, endDate.timeIntervalSince(now))
        remaining = newRemaining
        if newRemaining <= 0 {
            finish()
        }
    }

    private func finish() {
        isRunning = false
        endDate = nil
        remaining = 0
        if !didFinish {
            didFinish = true
        }
        stopTimerLoop()
        persist()
    }

    private func startTimerLoop() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(now: now)
            }
    }

    private func stopTimerLoop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}

#Preview {
    ContentView()
        .environmentObject(PurchaseManager(startTasks: false))
        .environmentObject(RoutineSelectionStore())
        .modelContainer(for: [Routine.self, RoutineClassification.self], inMemory: true)
}

enum Layout {
    static let sectionSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 16
    static let cardCornerRadius: CGFloat = 20
    static let rowSpacing: CGFloat = 12
    static let metricSpacing: CGFloat = 12
    static let metricPadding: CGFloat = 12
    static let metricCornerRadius: CGFloat = 16
    static let metricValueSize: CGFloat = 34
    static let timerFontSize: CGFloat = 72
    static let timerPadding: CGFloat = 16
    static let buttonSpacing: CGFloat = 12
    static let minTapHeight: CGFloat = 44
    static let controlsVerticalPadding: CGFloat = 12
    static let primaryButtonHeight: CGFloat = 80
    static let buttonCornerRadius: CGFloat = 16
    static let scrollBottomPadding: CGFloat = 24 + primaryButtonHeight
    static let defaultStepperControlSize = CGSize(width: 94, height: 32)
    static let wheelCornerRadius: CGFloat = 10
    static let wheelTickSpacing: CGFloat = 6
    static let wheelTickWidth: CGFloat = 2
    static let wheelTickHeightSmall: CGFloat = 8
    static let wheelTickHeightLarge: CGFloat = 14
    static let wheelTrackHeight: CGFloat = 12
    static let wheelTrackInset: CGFloat = 8
    static let wheelTrackVerticalInset: CGFloat = 6
    static let wheelTrackStrokeWidth: CGFloat = 1
    static let wheelThumbSize = CGSize(width: 16, height: 16)
    static let wheelThumbStrokeWidth: CGFloat = 1
    static let wheelStepDivisor: CGFloat = 6
    static let wheelStepMinWidth: CGFloat = 10
    static let wheelHitTarget: CGFloat = 44
    static let wheelClipInset: CGFloat = 1
    static let resetIconSize: CGFloat = 20
    static let resetIconCornerRadius: CGFloat = 6
    static let resetTapWidth: CGFloat = 44
}

enum Theme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let controlsBackground = Color(uiColor: .systemBackground)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let divider = Color(uiColor: .separator)
    static let iconTint = Color(uiColor: .systemBlue)
    static let iconBackground = Color(uiColor: .tertiarySystemFill)
    static let training = Color(uiColor: .systemTeal)
    static let resting = Color(uiColor: .systemOrange)
    static let completed = Color(uiColor: .systemGreen)
    static let primaryButton = Color(uiColor: .systemBlue)
    static let primaryButtonPressed = Color(uiColor: .systemBlue).opacity(0.85)
    static let primaryButtonDisabled = Color(uiColor: .systemGray4)
    static let primaryButtonText = Color.white
    static let secondaryButtonFill = Color(uiColor: .secondarySystemBackground)
    static let secondaryButtonBorder = Color(uiColor: .systemGray3)
    static let metricBackground = Color(uiColor: .tertiarySystemBackground)
    static let timerBackground = resting.opacity(0.12)
    static let cardBorder = Color(uiColor: .separator).opacity(0.3)
    static let cardShadow = Color.black.opacity(0.08)
    static let wheelBackground = Color(uiColor: .tertiarySystemBackground)
    static let wheelStroke = Color(uiColor: .systemGray4)
    static let wheelTick = Color(uiColor: .systemGray2)
    static let wheelIndicator = Color(uiColor: .systemBlue)
    static let wheelTrack = Color(uiColor: .secondarySystemFill)
    static let wheelTrackStroke = Color(uiColor: .systemGray4)
    static let wheelFill = wheelIndicator.opacity(0.2)
    static let wheelThumb = wheelIndicator
    static let wheelThumbStroke = Color.white.opacity(0.75)
}

struct ConfigRow<ValueContent: View>: View {
    let icon: String
    let titleKey: String
    let valueContent: ValueContent

    init(icon: String, titleKey: String, @ViewBuilder valueContent: () -> ValueContent) {
        self.icon = icon
        self.titleKey = titleKey
        self.valueContent = valueContent()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.iconTint)
                .frame(width: 28, height: 28)
                .background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(LocalizedStringKey(titleKey))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            valueContent
        }
    }
}

struct ConfigValueEditorButton: View {
    let titleKey: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let valueFormatter: ((Int) -> String)?
    let accessibilityIdentifier: String?
    let editorPickerIdentifier: String?

    @State private var isPresenting = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        titleKey: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        valueFormatter: ((Int) -> String)? = nil,
        accessibilityIdentifier: String? = nil,
        editorPickerIdentifier: String? = nil
    ) {
        self.titleKey = titleKey
        _value = value
        self.range = range
        self.step = step
        self.valueFormatter = valueFormatter
        self.accessibilityIdentifier = accessibilityIdentifier
        self.editorPickerIdentifier = editorPickerIdentifier
    }

    var body: some View {
        let formattedValue = valueFormatter?(value) ?? "\(value)"
        let button = Button {
            isPresenting = true
        } label: {
            Text(formattedValue)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .accessibilityLabel(L10n.format("accessibility.edit_value_label_format", L10n.tr(titleKey)))
        .accessibilityValue(formattedValue)

        Group {
            if horizontalSizeClass == .regular {
                button.popover(isPresented: $isPresenting, arrowEdge: .bottom) {
                    DiscreteValueEditor(
                        titleKey: titleKey,
                        value: $value,
                        range: range,
                        step: step,
                        valueFormatter: valueFormatter,
                        pickerIdentifier: editorPickerIdentifier
                    )
                    .frame(minWidth: 260, minHeight: 320)
                }
            } else {
                button.sheet(isPresented: $isPresenting) {
                    DiscreteValueEditor(
                        titleKey: titleKey,
                        value: $value,
                        range: range,
                        step: step,
                        valueFormatter: valueFormatter,
                        pickerIdentifier: editorPickerIdentifier
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }
}

struct DiscreteValueEditor: View {
    let titleKey: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let valueFormatter: ((Int) -> String)?
    let pickerIdentifier: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int

    init(
        titleKey: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        valueFormatter: ((Int) -> String)? = nil,
        pickerIdentifier: String? = nil
    ) {
        self.titleKey = titleKey
        _value = value
        self.range = range
        self.step = step
        self.valueFormatter = valueFormatter
        self.pickerIdentifier = pickerIdentifier
        let initial = DiscreteValueHelper.clampAndRound(value.wrappedValue, range: range, step: step)
        _selection = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(LocalizedStringKey(titleKey), selection: $selection) {
                    ForEach(DiscreteValueHelper.values(range: range, step: step), id: \.self) { option in
                        Text(valueFormatter?(option) ?? "\(option)")
                            .tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .accessibilityIdentifier(pickerIdentifier ?? "")
            }
            .navigationTitle(LocalizedStringKey(titleKey))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.ok") {
                        value = DiscreteValueHelper.clampAndRound(selection, range: range, step: step)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selection = DiscreteValueHelper.clampAndRound(value, range: range, step: step)
        }
    }
}

enum DiscreteValueHelper {
    static func clampAndRound(_ candidate: Int, range: ClosedRange<Int>, step: Int) -> Int {
        let minValue = range.lowerBound
        let maxValue = range.upperBound
        let clamped = min(max(candidate, minValue), maxValue)
        guard step > 0 else { return clamped }
        let maxStepIndex = max(0, (maxValue - minValue) / step)
        let offset = clamped - minValue
        let roundedIndex = Int((Double(offset) / Double(step)).rounded())
        let clampedIndex = min(max(roundedIndex, 0), maxStepIndex)
        return minValue + clampedIndex * step
    }

    static func values(range: ClosedRange<Int>, step: Int) -> [Int] {
        guard step > 0 else { return [range.lowerBound] }
        let maxStepIndex = max(0, (range.upperBound - range.lowerBound) / step)
        return (0...maxStepIndex).map { range.lowerBound + $0 * step }
    }
}

struct HorizontalWheelStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let controlSize: CGSize
    let accessibilityLabel: String
    let accessibilityValue: String
    let trackColor: Color = Theme.wheelTrack
    let trackStroke: Color = Theme.wheelTrackStroke
    let fillColor: Color = Theme.wheelFill
    let thumbColor: Color = Theme.wheelThumb
    let thumbStroke: Color = Theme.wheelThumbStroke
    let trackHeight: CGFloat = Layout.wheelTrackHeight
    let trackInset: CGFloat = Layout.wheelTrackInset
    let thumbSize: CGSize = Layout.wheelThumbSize

    @Environment(\.isEnabled) private var isEnabled
    @State private var dragStartValue: Int? = nil
    @State private var dragTranslation: CGFloat = 0

    private var resolvedSize: CGSize {
        controlSize == .zero ? Layout.defaultStepperControlSize : controlSize
    }

    private var normalizedProgress: CGFloat {
        let span = CGFloat(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        let progress = CGFloat(value - range.lowerBound) / span
        return min(max(progress, 0), 1)
    }

    var body: some View {
        let size = resolvedSize
        let stepWidth = max(Layout.wheelStepMinWidth, size.width / Layout.wheelStepDivisor)
        let tickPitch = Layout.wheelTickSpacing + Layout.wheelTickWidth
        let hitPaddingX = max(0, (Layout.wheelHitTarget - size.width) / 2)
        let hitPaddingY = max(0, (Layout.wheelHitTarget - size.height) / 2)
        let progress = normalizedProgress
        let safeTrackInset = max(trackInset, thumbSize.width / 2)
        let trackWidth = max(0, size.width - safeTrackInset * 2)
        let maxTrackHeight = max(0, size.height - Layout.wheelTrackVerticalInset * 2)
        let resolvedTrackHeight = max(0, min(trackHeight, maxTrackHeight))
        let fillWidth = trackWidth * progress
        let thumbOffsetX = trackWidth == 0 ? 0 : (-trackWidth / 2 + trackWidth * progress)

        ZStack {
            RoundedRectangle(cornerRadius: Layout.wheelCornerRadius, style: .continuous)
                .fill(Theme.wheelBackground)
            RoundedRectangle(cornerRadius: Layout.wheelCornerRadius, style: .continuous)
                .stroke(Theme.wheelStroke, lineWidth: 1)

            Capsule()
                .fill(trackColor)
                .frame(width: trackWidth, height: resolvedTrackHeight)
                .overlay(
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(fillColor)
                            .frame(width: fillWidth, height: resolvedTrackHeight)
                        Canvas { context, canvasSize in
                            let tickHeight = min(Layout.wheelTickHeightSmall, max(0, canvasSize.height - 4))
                            guard tickHeight > 0 else { return }
                            let phase = dragTranslation.truncatingRemainder(dividingBy: tickPitch)
                            let startX = -tickPitch * 2 + phase
                            let endX = canvasSize.width + tickPitch * 2
                            let y = (canvasSize.height - tickHeight) / 2

                            var x = startX
                            while x <= endX {
                                let rect = CGRect(x: x, y: y, width: Layout.wheelTickWidth, height: tickHeight)
                                let path = Path(roundedRect: rect, cornerRadius: Layout.wheelTickWidth / 2)
                                context.fill(path, with: .color(Theme.wheelTick))
                                x += tickPitch
                            }
                        }
                    }
                    .frame(width: trackWidth, height: resolvedTrackHeight)
                    .clipShape(Capsule())
                )
                .overlay(
                    Capsule()
                        .stroke(trackStroke, lineWidth: Layout.wheelTrackStrokeWidth)
                )

            Capsule()
                .fill(thumbColor)
                .frame(width: thumbSize.width, height: thumbSize.height)
                .overlay(
                    Capsule()
                        .stroke(thumbStroke, lineWidth: Layout.wheelThumbStrokeWidth)
                )
                .offset(x: thumbOffsetX)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(HitTargetShape(xPadding: hitPaddingX, yPadding: hitPaddingY))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    guard isEnabled else { return }
                    if dragStartValue == nil {
                        dragStartValue = value
                    }
                    dragTranslation = gesture.translation.width
                    let stepDelta = Int((gesture.translation.width / stepWidth).rounded())
                    let newValue = clampedValue((dragStartValue ?? value) + stepDelta * step)
                    if newValue != value {
                        value = newValue
                    }
                }
                .onEnded { gesture in
                    guard isEnabled else { return }
                    let startValue = dragStartValue ?? value
                    let predicted = gesture.predictedEndTranslation.width
                    let stepDelta = Int((predicted / stepWidth).rounded())
                    dragTranslation = predicted
                    value = clampedValue(startValue + stepDelta * step)
                    dragStartValue = nil
                    withAnimation(.snappy) {
                        dragTranslation = 0
                    }
                }
        )
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = clampedValue(value + step)
            case .decrement:
                value = clampedValue(value - step)
            default:
                break
            }
        }
    }

    private func clampedValue(_ candidate: Int) -> Int {
        let minValue = range.lowerBound
        let maxValue = range.upperBound
        let clamped = min(max(candidate, minValue), maxValue)
        let remainder = (clamped - minValue) % step
        return clamped - remainder
    }
}

private struct HitTargetShape: Shape {
    let xPadding: CGFloat
    let yPadding: CGFloat

    func path(in rect: CGRect) -> Path {
        let hitRect = rect.insetBy(dx: -xPadding, dy: -yPadding)
        return Path(hitRect)
    }
}

private struct MetricView: View {
    let titleKey: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: Layout.metricValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.metricPadding)
        .background(Theme.metricBackground, in: RoundedRectangle(cornerRadius: Layout.metricCornerRadius, style: .continuous))
    }
}

private struct SectionCard<Content: View, Trailing: View>: View {
    let titleKey: String
    let systemImage: String
    let trailing: Trailing
    let hasTrailing: Bool
    let content: Content

    init(titleKey: String, systemImage: String, @ViewBuilder content: () -> Content) where Trailing == EmptyView {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.trailing = EmptyView()
        self.hasTrailing = false
        self.content = content()
    }

    init(titleKey: String, systemImage: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.trailing = trailing()
        self.hasTrailing = true
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            if hasTrailing {
                HStack(spacing: 10) {
                    Label(LocalizedStringKey(titleKey), systemImage: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .symbolRenderingMode(.hierarchical)
                    Spacer(minLength: 0)
                    trailing
                }
            } else {
                Label(LocalizedStringKey(titleKey), systemImage: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .symbolRenderingMode(.hierarchical)
            }
            content
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 12, x: 0, y: 6)
    }
}

private struct ResetIconButton: View {
    let action: () -> Void
    let isEnabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: Layout.resetIconSize, height: Layout.resetIconSize)
                .background(
                    RoundedRectangle(cornerRadius: Layout.resetIconCornerRadius, style: .continuous)
                        .fill(Theme.secondaryButtonFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.resetIconCornerRadius, style: .continuous)
                                .stroke(Theme.secondaryButtonBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.borderless)
        .frame(width: Layout.resetTapWidth, alignment: .trailing)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0)
        .disabled(!isEnabled)
        .accessibilityHidden(!isEnabled)
        .accessibilityLabel(Text("accessibility.reset_label"))
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let height: CGFloat

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.primaryButtonText)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous)
                    .fill(isEnabled ? (configuration.isPressed ? Theme.primaryButtonPressed : Theme.primaryButton) : Theme.primaryButtonDisabled)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: Theme.primaryButton.opacity(isEnabled ? 0.25 : 0), radius: 10, x: 0, y: 6)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct StepperSizeReader: View {
    @Binding var size: CGSize

    var body: some View {
        Stepper("", value: .constant(0))
            .labelsHidden()
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: StepperSizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(StepperSizeKey.self) { newSize in
                if newSize != .zero && newSize != size {
                    size = newSize
                }
            }
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct StepperSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
