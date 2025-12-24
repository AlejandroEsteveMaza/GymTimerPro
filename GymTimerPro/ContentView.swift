//
//  ContentView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 24/12/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var totalSeries: Int = 4
    @State private var tiempoDescanso: Int = 90
    @State private var serieActual: Int = 1
    @State private var descansando: Bool = false
    @State private var tiempoRestante: Int = 0
    @State private var timer: Timer? = nil
    @State private var completado: Bool = false

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
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            self.stopTimer()
        }
        .onChange(of: totalSeries) { _, newValue in
            if self.serieActual > newValue {
                self.serieActual = newValue
            }
            if self.serieActual < 1 {
                self.serieActual = 1
            }
        }
    }

    private var configurationSection: some View {
        SectionCard(title: "Configuración", systemImage: "slider.horizontal.3") {
            VStack(spacing: Layout.rowSpacing) {
                configStepper(
                    title: "Series totales",
                    icon: "square.stack.3d.up",
                    value: $totalSeries,
                    range: 1...10
                )
                Divider()
                    .foregroundStyle(Theme.divider)
                configStepper(
                    title: "Descanso (segundos)",
                    icon: "timer",
                    value: $tiempoDescanso,
                    range: 15...300,
                    step: 15
                )
            }
        }
        .disabled(isTimerActive || completado)
        .opacity(isTimerActive || completado ? 0.55 : 1.0)
        .tint(Theme.primaryButton)
    }

    private var progressSection: some View {
        SectionCard(title: "Progreso", systemImage: "chart.line.uptrend.xyaxis") {
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

                    if descansando {
                        restTimerView
                    }
                }
            }
        }
        .animation(.snappy, value: descansando)
        .animation(.snappy, value: completado)
    }

    private var controlsSection: some View {
        VStack(spacing: Layout.buttonSpacing) {
            Button(action: startRest) {
                Label("EMPEZAR DESCANSO", systemImage: "pause.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle(height: Layout.primaryButtonHeight))
            .disabled(descansando || completado)

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

    private func configStepper(
        title: String,
        icon: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            ConfigRow(icon: icon, title: title, value: "\(value.wrappedValue)")
        }
        .frame(minHeight: Layout.minTapHeight)
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
        if descansando {
            return ("DESCANSANDO", "hourglass", Theme.resting)
        }
        return ("ENTRENANDO", "figure.walk", Theme.training)
    }

    private var restTimerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tiempo de descanso", systemImage: "timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .symbolRenderingMode(.hierarchical)

            Text("\(tiempoRestante)")
                .font(.system(size: Layout.timerFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.resting)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.9), value: tiempoRestante)
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
        timer != nil
    }

    private func startRest() {
        guard !descansando, !completado, timer == nil else { return }

        if serieActual >= totalSeries {
            completeWorkout()
            return
        }

        withAnimation(.snappy) {
            serieActual += 1
            descansando = true
            tiempoRestante = tiempoDescanso
        }

        // Timer for the rest countdown.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.tiempoRestante > 0 {
                self.tiempoRestante -= 1
            }

            if self.tiempoRestante == 0 {
                self.endRest()
            }
        }
    }

    private func endRest() {
        guard descansando else { return }
        stopTimer()

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.snappy) {
            descansando = false
            tiempoRestante = 0
        }
    }

    private func completeWorkout() {
        stopTimer()

        withAnimation(.snappy) {
            completado = true
            descansando = false
            tiempoRestante = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.completado {
                self.resetWorkout()
            }
        }
    }

    private func resetWorkout() {
        stopTimer()

        withAnimation(.snappy) {
            serieActual = 1
            descansando = false
            tiempoRestante = 0
            completado = false
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
