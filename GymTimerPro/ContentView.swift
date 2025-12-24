//
//  ContentView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 24/12/25.
//

import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @State private var totalSeries: Int = 4
    @State private var tiempoDescanso: Int = 90
    @State private var serieActual: Int = 1
    @State private var completado: Bool = false
    @State private var stepperControlSize: CGSize = Layout.defaultStepperControlSize
    @StateObject private var restTimer = RestTimerModel()
    @StateObject private var liveActivityManager = LiveActivityManager()

    @Environment(\.scenePhase) private var scenePhase

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
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controlsSection
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            restoreLiveActivityIfNeeded()
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
        .onChange(of: scenePhase) { _, newPhase in
            restTimer.handleScenePhase(newPhase)
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
    }

    private var configurationSection: some View {
        SectionCard(title: "Configuración", systemImage: "slider.horizontal.3") {
            VStack(spacing: Layout.rowSpacing) {
                configWheelRow(
                    title: "Series totales",
                    icon: "square.stack.3d.up",
                    value: $totalSeries,
                    range: 1...10,
                    accessibilityValue: "\(totalSeries) series"
                )
                Divider()
                    .foregroundStyle(Theme.divider)
                configWheelRow(
                    title: "Descanso (segundos)",
                    icon: "timer",
                    value: $tiempoDescanso,
                    range: 15...300,
                    step: 15,
                    accessibilityValue: "\(tiempoDescanso) segundos"
                )
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
        SectionCard(title: "Progreso", systemImage: "chart.line.uptrend.xyaxis") {
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
                Label("EMPEZAR DESCANSO", systemImage: "pause.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle(height: Layout.primaryButtonHeight))
            .disabled(isResting || completado)

            Button(action: resetWorkout) {
                Label("REINICIAR", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SecondaryButtonStyle(height: Layout.secondaryButtonHeight))
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
        title: String,
        icon: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        accessibilityValue: String
    ) -> some View {
        HStack(spacing: 12) {
            ConfigRow(icon: icon, title: title, value: "\(value.wrappedValue)")
                .layoutPriority(1)
                .accessibilityHidden(true)
            HorizontalWheelStepper(
                value: value,
                range: range,
                step: step,
                controlSize: stepperControlSize,
                accessibilityLabel: title,
                accessibilityValue: accessibilityValue
            )
        }
        .frame(minHeight: Layout.minTapHeight)
    }

    @ViewBuilder
    private func progressContent(now: Date) -> some View {
        if completado {
            completionView
                .transition(.opacity.combined(with: .scale))
        } else {
            VStack(alignment: .leading, spacing: Layout.metricSpacing) {
                HStack(spacing: Layout.metricSpacing) {
                    MetricView(title: "SERIE", value: "\(serieActual) / \(totalSeries)")
                }

                HStack(spacing: 12) {
                    Text("Estado")
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
        return Label(status.text, systemImage: status.icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.15), in: Capsule())
            .foregroundStyle(status.color)
            .symbolRenderingMode(.hierarchical)
    }

    private var statusStyle: (text: String, icon: String, color: Color) {
        if isResting {
            return ("DESCANSANDO", "hourglass", Theme.resting)
        }
        return ("ENTRENANDO", "figure.walk", Theme.training)
    }

    private func restTimerView(remainingSeconds: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tiempo de descanso", systemImage: "timer")
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
    }

    private var completionView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.completed)
                .symbolRenderingMode(.hierarchical)
            Text("¡ENTRENAMIENTO COMPLETADO!")
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

    private func startRest() {
        guard !isResting, !completado else { return }

        if serieActual >= totalSeries {
            completeWorkout()
            return
        }

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
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func completeWorkout() {
        restTimer.reset()
        liveActivityManager.end()

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

        withAnimation(.snappy) {
            serieActual = 1
            completado = false
        }
    }

    private func restoreLiveActivityIfNeeded() {
        guard restTimer.isRunning, let endDate = restTimer.endDate else { return }
        updateLiveActivity(endDate: endDate, mode: .resting)
    }

    private func updateLiveActivity(endDate: Date, mode: GymTimerAttributes.Mode) {
        liveActivityManager.startOrUpdate(
            currentSet: serieActual,
            totalSets: totalSeries,
            endDate: endDate,
            mode: mode
        )
    }
}

// Countdown state is derived from endDate; remaining is stored for paused state and persistence.
private final class RestTimerModel: ObservableObject {
    @Published private(set) var isRunning: Bool
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var endDate: Date?
    @Published var didFinish: Bool = false

    private let storage: UserDefaults

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
        persist()
    }

    func pause(now: Date = .now) {
        guard isRunning, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSince(now))
        self.endDate = nil
        isRunning = false
        persist()
    }

    func resume(now: Date = .now) {
        guard !isRunning, remaining > 0 else { return }
        endDate = now.addingTimeInterval(remaining)
        isRunning = true
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
        persist()
    }
}

#Preview {
    ContentView()
}

private enum Layout {
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
    static let secondaryButtonHeight: CGFloat = 56
    static let buttonCornerRadius: CGFloat = 16
    static let scrollBottomPadding: CGFloat = 24 + primaryButtonHeight + secondaryButtonHeight
    static let defaultStepperControlSize = CGSize(width: 94, height: 32)
    static let wheelCornerRadius: CGFloat = 10
    static let wheelTickSpacing: CGFloat = 6
    static let wheelTickWidth: CGFloat = 2
    static let wheelTickHeightSmall: CGFloat = 8
    static let wheelTickHeightLarge: CGFloat = 14
    static let wheelStepDivisor: CGFloat = 6
    static let wheelStepMinWidth: CGFloat = 10
    static let wheelHitTarget: CGFloat = 44
    static let wheelClipInset: CGFloat = 1
}

private enum Theme {
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
}

private struct ConfigRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.iconTint)
                .frame(width: 28, height: 28)
                .background(Theme.iconBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
    }
}

private struct HorizontalWheelStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let controlSize: CGSize
    let accessibilityLabel: String
    let accessibilityValue: String

    @Environment(\.isEnabled) private var isEnabled
    @State private var dragStartValue: Int? = nil
    @State private var dragTranslation: CGFloat = 0

    private var resolvedSize: CGSize {
        controlSize == .zero ? Layout.defaultStepperControlSize : controlSize
    }

    var body: some View {
        let size = resolvedSize
        let stepWidth = max(Layout.wheelStepMinWidth, size.width / Layout.wheelStepDivisor)
        let tickPitch = Layout.wheelTickSpacing + Layout.wheelTickWidth
        let hitPaddingX = max(0, (Layout.wheelHitTarget - size.width) / 2)
        let hitPaddingY = max(0, (Layout.wheelHitTarget - size.height) / 2)

        ZStack {
            RoundedRectangle(cornerRadius: Layout.wheelCornerRadius, style: .continuous)
                .fill(Theme.wheelBackground)
            RoundedRectangle(cornerRadius: Layout.wheelCornerRadius, style: .continuous)
                .stroke(Theme.wheelStroke, lineWidth: 1)

            Canvas { context, canvasSize in
                let inset = Layout.wheelClipInset
                let clipRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: inset, dy: inset)
                let radius = max(0, Layout.wheelCornerRadius - inset)
                let clipPath = Path(roundedRect: clipRect, cornerRadius: radius)
                context.clip(to: clipPath)

                let phase = dragTranslation.truncatingRemainder(dividingBy: tickPitch)
                let startX = -tickPitch * 2 + phase
                let endX = canvasSize.width + tickPitch * 2
                let tickHeight = Layout.wheelTickHeightSmall
                let y = (canvasSize.height - tickHeight) / 2

                var x = startX
                while x <= endX {
                    let rect = CGRect(x: x, y: y, width: Layout.wheelTickWidth, height: tickHeight)
                    let path = Path(roundedRect: rect, cornerRadius: Layout.wheelTickWidth / 2)
                    context.fill(path, with: .color(Theme.wheelTick))
                    x += tickPitch
                }
            }

            Capsule()
                .frame(width: Layout.wheelTickWidth, height: Layout.wheelTickHeightLarge + 6)
                .foregroundStyle(Theme.wheelIndicator)
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
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
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

private struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .symbolRenderingMode(.hierarchical)
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

private struct SecondaryButtonStyle: ButtonStyle {
    let height: CGFloat

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous)
                    .fill(Theme.secondaryButtonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous)
                    .stroke(Theme.secondaryButtonBorder, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

private struct StepperSizeReader: View {
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

private struct StepperSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
