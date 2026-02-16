//
//  SettingsRootView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import SwiftUI

struct SettingsRootView: View {
    @AppStorage(WeightUnitPreference.appStorageKey) private var weightUnitPreferenceRawValue: Int = WeightUnitPreference.automatic.rawValue
    @AppStorage(MaxSetsPreference.appStorageKey) private var maxSetsPreferenceRawValue: Int = MaxSetsPreference.ten.rawValue
    @AppStorage(RestIncrementPreference.appStorageKey) private var restIncrementPreferenceRawValue: Int = RestIncrementPreference.fifteenSeconds.rawValue
    @AppStorage(TimerDisplayFormat.appStorageKey) private var timerDisplayFormatRawValue: Int = TimerDisplayFormat.seconds.rawValue
    @AppStorage(PowerSavingMode.appStorageKey) private var powerSavingModeRawValue: Int = PowerSavingMode.off.rawValue

    var body: some View {
        List {
            Section("settings.weight_unit.section") {
                Picker("settings.weight_unit.title", selection: weightUnitPreferenceBinding) {
                    Text("settings.weight_unit.option.automatic")
                        .tag(WeightUnitPreference.automatic)
                    Text("settings.weight_unit.option.kilograms")
                        .tag(WeightUnitPreference.kilograms)
                    Text("settings.weight_unit.option.pounds")
                        .tag(WeightUnitPreference.pounds)
                }
                .pickerStyle(.menu)
            }

            Section("settings.timer_display.section") {
                Picker("settings.timer_display.title", selection: timerDisplayFormatBinding) {
                    Text("settings.timer_display.option.seconds")
                        .tag(TimerDisplayFormat.seconds)
                    Text("settings.timer_display.option.minutes_seconds")
                        .tag(TimerDisplayFormat.minutesAndSeconds)
                }
                .pickerStyle(.segmented)
            }

            Section("settings.max_sets.section") {
                Picker("settings.max_sets.title", selection: maxSetsPreferenceBinding) {
                    Text("settings.max_sets.option.10")
                        .tag(MaxSetsPreference.ten)
                    Text("settings.max_sets.option.15")
                        .tag(MaxSetsPreference.fifteen)
                    Text("settings.max_sets.option.20")
                        .tag(MaxSetsPreference.twenty)
                    Text("settings.max_sets.option.30")
                        .tag(MaxSetsPreference.thirty)
                }
                .pickerStyle(.menu)
            }

            Section("settings.rest_increment.section") {
                Picker("settings.rest_increment.title", selection: restIncrementPreferenceBinding) {
                    Text("settings.rest_increment.option.5")
                        .tag(RestIncrementPreference.fiveSeconds)
                    Text("settings.rest_increment.option.10")
                        .tag(RestIncrementPreference.tenSeconds)
                    Text("settings.rest_increment.option.15")
                        .tag(RestIncrementPreference.fifteenSeconds)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Picker("settings.energy.mode.title", selection: powerSavingModeBinding) {
                    Text("settings.energy.mode.off")
                        .tag(PowerSavingMode.off)
                    Text("settings.energy.mode.automatic")
                        .tag(PowerSavingMode.automatic)
                    Text("settings.energy.mode.on")
                        .tag(PowerSavingMode.on)
                }
                .pickerStyle(.menu)
            } header: {
                Text("settings.energy.section")
            } footer: {
                Text("settings.energy.description")
            }

            Section {
                NavigationLink {
                    RoutineClassificationManagerView()
                } label: {
                    Text("classifications.manage.title")
                }
            }
        }
        .navigationTitle("tab.settings")
    }

    private var weightUnitPreferenceBinding: Binding<WeightUnitPreference> {
        Binding(
            get: { WeightUnitPreference(rawValue: weightUnitPreferenceRawValue) ?? .automatic },
            set: { weightUnitPreferenceRawValue = $0.rawValue }
        )
    }

    private var timerDisplayFormatBinding: Binding<TimerDisplayFormat> {
        Binding(
            get: { TimerDisplayFormat(rawValue: timerDisplayFormatRawValue) ?? .seconds },
            set: { timerDisplayFormatRawValue = $0.rawValue }
        )
    }

    private var maxSetsPreferenceBinding: Binding<MaxSetsPreference> {
        Binding(
            get: { MaxSetsPreference(rawValue: maxSetsPreferenceRawValue) ?? .ten },
            set: { maxSetsPreferenceRawValue = $0.rawValue }
        )
    }

    private var restIncrementPreferenceBinding: Binding<RestIncrementPreference> {
        Binding(
            get: { RestIncrementPreference(rawValue: restIncrementPreferenceRawValue) ?? .fifteenSeconds },
            set: { restIncrementPreferenceRawValue = $0.rawValue }
        )
    }

    private var powerSavingModeBinding: Binding<PowerSavingMode> {
        Binding(
            get: { PowerSavingMode(rawValue: powerSavingModeRawValue) ?? .off },
            set: { powerSavingModeRawValue = $0.rawValue }
        )
    }
}

#Preview {
    NavigationStack {
        SettingsRootView()
    }
}
