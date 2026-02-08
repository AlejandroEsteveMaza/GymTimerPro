//
//  GymTimerProApp.swift
//  GymTimerPro
//
//  Created by Alejandro Esteve Maza on 24/12/25.
//

import OSLog
import SwiftData
import SwiftUI

@main
struct GymTimerProApp: App {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GymTimerPro",
        category: "SwiftData"
    )
    private static let cloudKitContainerIdentifier = "iCloud.alejandroestevemaza.GymTimerPro"

    private let modelContainer: ModelContainer

    @StateObject private var purchaseManager = PurchaseManager()
    @StateObject private var routineSelectionStore = RoutineSelectionStore()

    init() {
        let container = Self.makeModelContainer()
        self.modelContainer = container
#if DEBUG
        Task { @MainActor in
            ProgressDebugSeeder.runIfNeeded(modelContainer: container)
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(purchaseManager)
                .environmentObject(routineSelectionStore)
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Routine.self,
            RoutineClassification.self,
            WorkoutCompletion.self,
            GoalSettings.self
        ])

        // Use a stable on-disk URL so the fallback local-only config can open the same store file.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let storeURL = appSupport.appendingPathComponent("GymTimerPro.store")

        do {
            let cloudConfig = ModelConfiguration(
                "GymTimerPro",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            logger.info("SwiftData ModelContainer initialized with CloudKit (private database).")
            return container
        } catch {
            logger.error("SwiftData CloudKit store failed. Falling back to local-only. Error: \(String(describing: error))")
            do {
                let localConfig = ModelConfiguration(
                    "GymTimerPro",
                    schema: schema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                logger.info("SwiftData ModelContainer initialized local-only.")
                return container
            } catch {
                logger.error("SwiftData local store failed. Falling back to in-memory. Error: \(String(describing: error))")
                do {
                    let memoryConfig = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                    let container = try ModelContainer(for: schema, configurations: [memoryConfig])
                    logger.info("SwiftData ModelContainer initialized in-memory.")
                    return container
                } catch {
                    // This should be extremely rare (e.g. disk full / corrupted store) and is not recoverable.
                    fatalError("Unable to create SwiftData ModelContainer: \(error)")
                }
            }
        }
    }
}
