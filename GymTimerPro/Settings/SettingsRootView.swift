//
//  SettingsRootView.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 27/01/26.
//

import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        List {
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
}

#Preview {
    NavigationStack {
        SettingsRootView()
    }
}
