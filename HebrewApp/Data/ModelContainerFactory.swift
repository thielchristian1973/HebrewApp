import Foundation
import SwiftData

enum ModelContainerFactory {
    /// `cloudKitDatabase: .none` is explicit: the pilot's local-only progress store must never
    /// silently start syncing before optional iCloud sync is deliberately built
    /// (Documentation/PRIVACY_AND_RELEASE.md: opt-in only, "Private CloudKit-Datenbank nur für
    /// Progress/Settings" — and only in a later phase).
    static func makeContainer(inMemory: Bool = false) throws(PersistenceError) -> ModelContainer {
        let schema = Schema(PilotSchemaV1.models)
        let configuration = ModelConfiguration(
            "HebrewAppPilot",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, migrationPlan: PilotMigrationPlan.self, configurations: [configuration])
        } catch {
            throw PersistenceError.saveFailed("ModelContainer init failed: \(error)")
        }
    }
}
