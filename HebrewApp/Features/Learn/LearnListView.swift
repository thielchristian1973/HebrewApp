import SwiftUI

struct LearnListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var progressByPathID: [String: PilotLearningPathProgress] = [:]

    var body: some View {
        List {
            Section {
                Text("Zwei Demo-Lernstrecken aus dem Pilotmaterial — keine vollständigen A0-Lektionen.")
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(completedPathsSummary)
                    .font(AppFont.germanBody().weight(.semibold))
            }
            Section("Demo-Lernstrecken") {
                ForEach(PilotLearningPathCatalog.all) { path in
                    NavigationLink(value: path.id) {
                        pathRow(path)
                    }
                }
            }
            Section("Weiteres") {
                NavigationLink("Grammatiknachschlagewerk") { GrammarView() }
                NavigationLink("Wiederholung") { ReviewView() }
            }
        }
        .navigationDestination(for: String.self) { pathID in
            if let path = PilotLearningPathCatalog.all.first(where: { $0.id == pathID }) {
                PilotPathPlayerView(path: path)
            }
        }
        .task { await loadProgress() }
    }

    private func pathRow(_ path: PilotLearningPath) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(path.title)
                .font(AppFont.germanBody().weight(.semibold))
            Text(path.objective)
                .font(AppFont.germanCaption())
                .foregroundStyle(ColorTokens.textSecondary)
            if let progress = progressByPathID[path.id] {
                ProgressView(value: Double(progress.completedStepIDs.count), total: Double(path.steps.count))
                    .tint(ColorTokens.primary)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var completedPathsSummary: String {
        let paths = PilotLearningPathCatalog.all
        let completed = PilotPathProgressTracker.completedPathCount(paths: paths, progress: Array(progressByPathID.values))
        return "\(completed) von \(paths.count) Lernstrecken abgeschlossen"
    }

    private func loadProgress() async {
        for path in PilotLearningPathCatalog.all {
            let progress = (try? await environment.progressRepository.loadPathProgress(pathID: path.id))
                ?? PilotLearningPathProgress(pathID: path.id)
            progressByPathID[path.id] = progress
        }
    }
}
