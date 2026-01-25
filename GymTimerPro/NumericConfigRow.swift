//
//  NumericConfigRow.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/12/25.
//

import SwiftUI

struct NumericConfigRow: View {
    let titleKey: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let accessibilityValue: String
    @Binding var stepperControlSize: CGSize
    let valueFormatter: ((Int) -> String)?
    let valueEditorIdentifier: String?
    let editorPickerIdentifier: String?

    init(
        titleKey: String,
        icon: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        accessibilityValue: String,
        stepperControlSize: Binding<CGSize>,
        valueFormatter: ((Int) -> String)? = nil,
        valueEditorIdentifier: String? = nil,
        editorPickerIdentifier: String? = nil
    ) {
        self.titleKey = titleKey
        self.icon = icon
        _value = value
        self.range = range
        self.step = step
        self.accessibilityValue = accessibilityValue
        _stepperControlSize = stepperControlSize
        self.valueFormatter = valueFormatter
        self.valueEditorIdentifier = valueEditorIdentifier
        self.editorPickerIdentifier = editorPickerIdentifier
    }

    var body: some View {
        let localizedTitle = L10n.tr(titleKey)
        HStack(spacing: 12) {
            ConfigRow(icon: icon, titleKey: titleKey) {
                ConfigValueEditorButton(
                    titleKey: titleKey,
                    value: $value,
                    range: range,
                    step: step,
                    valueFormatter: valueFormatter,
                    accessibilityIdentifier: valueEditorIdentifier,
                    editorPickerIdentifier: editorPickerIdentifier
                )
            }
            .layoutPriority(1)

            HorizontalWheelStepper(
                value: $value,
                range: range,
                step: step,
                controlSize: stepperControlSize,
                accessibilityLabel: localizedTitle,
                accessibilityValue: accessibilityValue
            )
        }
        .frame(minHeight: Layout.minTapHeight)
    }
}
