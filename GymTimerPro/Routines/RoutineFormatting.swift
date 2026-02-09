//
//  RoutineFormatting.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import Foundation

enum RoutineFormatting {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        return formatter
    }()

    static let measurementFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.locale = .current
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        formatter.numberFormatter = numberFormatter
        return formatter
    }()

    static func weightInputText(_ weightKg: Double?) -> String {
        guard let weightKg else { return "" }
        let displayValue = displayWeightValue(fromKilograms: weightKg)
        return numberFormatter.string(from: NSNumber(value: displayValue)) ?? "\(displayValue)"
    }

    static func weightValueText(_ weightKg: Double?) -> String {
        guard let weightKg else { return L10n.tr("routines.weight.empty") }
        let measurement = displayMeasurement(fromKilograms: weightKg)
        return measurementFormatter.string(from: measurement)
    }

    static func weightSummaryText(_ weightKg: Double?) -> String {
        guard let weightKg else { return L10n.tr("routines.weight.empty") }
        let measurement = displayMeasurement(fromKilograms: weightKg)
        return measurementFormatter.string(from: measurement)
    }

    static func parseWeight(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        if let number = numberFormatter.number(from: text) {
            return number.doubleValue
        }
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    static func weightKilograms(fromInputText text: String) -> Double? {
        guard let rawValue = parseWeight(text) else { return nil }
        let measurement = Measurement(value: rawValue, unit: resolvedWeightUnit())
        return measurement.converted(to: .kilograms).value
    }

    static func summaryText(sets: Int, reps: Int, restSeconds: Int, weightKg: Double?) -> String {
        let weightText = weightSummaryText(weightKg)
        let displayFormatRawValue = UserDefaults.standard.object(forKey: TimerDisplayFormat.appStorageKey) as? Int
            ?? TimerDisplayFormat.seconds.rawValue
        let displayFormat = TimerDisplayFormat(rawValue: displayFormatRawValue) ?? .seconds
        let formattedRest = TimerDisplayFormatter.string(from: restSeconds, format: displayFormat)
        return L10n.format("routines.summary_format", sets, reps, formattedRest, weightText)
    }

    private static func weightUnitPreference() -> WeightUnitPreference {
        let rawValue = UserDefaults.standard.object(forKey: WeightUnitPreference.appStorageKey) as? Int
            ?? WeightUnitPreference.automatic.rawValue
        return WeightUnitPreference(rawValue: rawValue) ?? .automatic
    }

    private static func resolvedWeightUnit() -> UnitMass {
        weightUnitPreference().resolvedUnit()
    }

    private static func displayWeightValue(fromKilograms valueInKg: Double) -> Double {
        let measurement = Measurement(value: valueInKg, unit: UnitMass.kilograms)
        return measurement.converted(to: resolvedWeightUnit()).value
    }

    private static func displayMeasurement(fromKilograms valueInKg: Double) -> Measurement<UnitMass> {
        let measurement = Measurement(value: valueInKg, unit: UnitMass.kilograms)
        return measurement.converted(to: resolvedWeightUnit())
    }
}
