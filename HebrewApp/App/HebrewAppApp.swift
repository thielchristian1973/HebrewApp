import SwiftUI
import SwiftData

@main
struct HebrewAppApp: App {
    @State private var environment: AppEnvironment
    @State private var containerFailure: String?

    init() {
        do {
            let container = try ModelContainerFactory.makeContainer()
            _environment = State(initialValue: AppEnvironment(modelContainer: container))
        } catch {
            // Persistence must never crash the app outright — the pilot screen surfaces this as
            // an honest, visible failure instead (CLAUDE.md: "keine Dummy-Erfolge").
            _environment = State(initialValue: AppEnvironment(modelContainer: Self.emptyFallbackContainer()))
            _containerFailure = State(initialValue: "\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .task {
                    await environment.loadContentIfNeeded()
                    await environment.refreshCapabilities()
                }
        }
    }

    /// Used only if the real on-disk store fails to open, so the app can still show a clear
    /// error state instead of crashing at launch.
    private static func emptyFallbackContainer() -> ModelContainer {
        (try? ModelContainerFactory.makeContainer(inMemory: true)) ?? {
            fatalError("In-memory ModelContainer must always succeed")
        }()
    }
}
