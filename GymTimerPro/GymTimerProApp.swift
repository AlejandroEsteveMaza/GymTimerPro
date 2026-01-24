//
//  GymTimerProApp.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 24/12/25.
//

import SwiftUI

@main
struct GymTimerProApp: App {
    @StateObject private var purchaseManager = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(purchaseManager)
        }
    }
}
