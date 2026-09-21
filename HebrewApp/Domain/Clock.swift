import Foundation

/// Injected time source (ARCHITECTURE.md: "Clock injiziert Zeit"). Lets tests exercise clock
/// rollback, timezone changes and DST without touching the system clock
/// (Documentation/LEARNING_ENGINE.md "Geräteuhr-Rücksprung/Zeitzonenwechsel/DST testen"). Named
/// `DateProviding` rather than `Clock` to avoid colliding with the Swift standard library's
/// `_Concurrency.Clock` protocol.
protocol DateProviding: Sendable {
    func now() -> Date
}

struct SystemDateProvider: DateProviding {
    func now() -> Date { Date() }
}
