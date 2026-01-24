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
        return numberFormatter.string(from: NSNumber(value: weightKg)) ?? "\(weightKg)"
    }

    static func weightValueText(_ weightKg: Double?) -> String {
        guard let weightKg else { return L10n.tr("routines.weight.empty") }
        return numberFormatter.string(from: NSNumber(value: weightKg)) ?? "\(weightKg)"
    }

    static func weightSummaryText(_ weightKg: Double?) -> String {
        guard let weightKg else { return L10n.tr("routines.weight.empty") }
        let measurement = Measurement(value: weightKg, unit: UnitMass.kilograms)
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

    static func summaryText(sets: Int, restSeconds: Int, weightKg: Double?) -> String {
        let weightText = weightSummaryText(weightKg)
        return L10n.format("routines.summary_format", sets, restSeconds, weightText)
    }
}
