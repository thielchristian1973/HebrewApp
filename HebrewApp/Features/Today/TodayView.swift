import SwiftUI

/// Navigation target for Today's links. Modelled as a hashable value pushed via
/// `NavigationLink(value:)` + `.navigationDestination(for:)` rather than the closure-based
/// `NavigationLink { dest } label: { ... }` initializer — the closure form was empirically found
/// not to respond to taps when combined with a custom `.buttonStyle` outside a `List` in this
/// app's view hierarchy, while the value-based form (also used by `LearnListView`) works
/// reliably.
enum TodayDestination: Hashable {
    case path(String)
    case pilotDeveloper
}

struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("developerModeEnabled") private var developerModeEnabled = Self.developerModeDefault
    @State private var nextPath: PilotLearningPath?
    @State private var pathProgress: [PilotLearningPathProgress] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if isLoading {
                    LoadingView(message: "Lade Pilotinhalte …")
                } else if let error = environment.contentLoadError {
                    ErrorStateView(
                        title: "Inhalte konnten nicht geladen werden",
                        detail: describeContentError(error)
                    )
                } else {
                    heroCard
                    reviewCard
                    if developerModeEnabled {
                        developerCard
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(ColorTokens.background)
        .navigationDestination(for: TodayDestination.self) { destination in
            switch destination {
            case .path(let pathID):
                if let path = PilotLearningPathCatalog.all.first(where: { $0.id == pathID }) {
                    PilotPathPlayerView(path: path)
                }
            case .pilotDeveloper:
                PilotDeveloperView()
            }
        }
        .task {
            await environment.loadContentIfNeeded()
            await updateNextPath()
            isLoading = false
        }
    }

    private var heroCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Weiterlernen")
                if let nextPath {
                    Text(nextPath.objective)
                        .font(AppFont.germanBody())
                        .foregroundStyle(ColorTokens.textSecondary)
                    Text(completedPathsSummary)
                        .font(AppFont.germanCaption())
                        .foregroundStyle(ColorTokens.textSecondary)
                    NavigationLink(value: TodayDestination.path(nextPath.id)) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "play.fill")
                            Text("\(nextPath.title) starten")
                                .font(AppFont.germanBody().weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTokens.primary)
                } else {
                    Text("Beide Demo-Lernstrecken sind abgeschlossen.")
                        .font(AppFont.germanBody())
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }

    private var reviewCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                SectionHeader(title: "Wiederholung")
                Text("Die verteilte Wiederholung ist Teil des Lernkerns (P2) und noch nicht Teil dieses Technik-Pilots.")
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    private var developerCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionHeader(title: "Entwicklermodus")
                Text("Pilot-Diagnose: Content, TTS, Aufnahme, lokale Spracherkennung, Tutor-Verfügbarkeit und Prüfbericht.")
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
                NavigationLink("Pilot-Diagnose öffnen", value: TodayDestination.pilotDeveloper)
            }
        }
    }

    private var completedPathsSummary: String {
        let paths = PilotLearningPathCatalog.all
        let completed = PilotPathProgressTracker.completedPathCount(paths: paths, progress: pathProgress)
        return "\(completed) von \(paths.count) Lernstrecken abgeschlossen"
    }

    private func updateNextPath() async {
        var loaded: [PilotLearningPathProgress] = []
        var firstIncomplete: PilotLearningPath?
        for path in PilotLearningPathCatalog.all {
            let progress = (try? await environment.progressRepository.loadPathProgress(pathID: path.id))
                ?? PilotLearningPathProgress(pathID: path.id)
            loaded.append(progress)
            if firstIncomplete == nil, !PilotPathProgressTracker.isComplete(path: path, progress: progress) {
                firstIncomplete = path
            }
        }
        pathProgress = loaded
        nextPath = firstIncomplete
    }

    private func describeContentError(_ error: ContentLoadError) -> String {
        switch error {
        case .resourceNotFound(let name): "Datei nicht gefunden: \(name)"
        case .decodingFailed(let detail): "Konnte nicht gelesen werden: \(detail)"
        case .hashMismatch(let file): "Prüfsumme stimmt nicht überein: \(file)"
        case .countMismatch(let expected, let actual, let kind): "\(kind): erwartet \(expected), gefunden \(actual)"
        case .duplicateID(let id): "Doppelte ID: \(id)"
        case .unsupportedSchemaVersion(let version): "Nicht unterstützte Schemaversion: \(version)"
        }
    }

    private static var developerModeDefault: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
