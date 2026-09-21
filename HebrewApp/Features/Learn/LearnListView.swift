import SwiftUI

struct LearnListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var progressByPathID: [String: PilotLearningPathProgress] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                introCard
                ForEach(Array(PilotLearningPathCatalog.all.enumerated()), id: \.element.id) { index, path in
                    NavigationLink(value: path.id) {
                        chapterCard(path, accentIndex: index)
                    }
                    .buttonStyle(.plain)
                }
                furtherCard
            }
            .padding(Spacing.md)
        }
        .background(ColorTokens.background)
        .navigationDestination(for: String.self) { pathID in
            if let path = PilotLearningPathCatalog.all.first(where: { $0.id == pathID }) {
                PilotPathPlayerView(path: path)
            }
        }
        .task { await loadProgress() }
    }

    private var introCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Zwei Demo-Lernstrecken aus dem Pilotmaterial — keine vollständigen A0-Lektionen.")
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(completedPathsSummary)
                    .font(AppFont.germanBody().weight(.semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }

    private func chapterCard(_ path: PilotLearningPath, accentIndex: Int) -> some View {
        let progress = progressByPathID[path.id] ?? PilotLearningPathProgress(pathID: path.id)
        let isComplete = PilotPathProgressTracker.isComplete(path: path, progress: progress)
        let isNext = !isComplete && path.id == nextIncompletePathID
        let tint = accentIndex % 2 == 0 ? ColorTokens.primary : ColorTokens.accent

        return CardView {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Spacing.sm, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: chapterIcon(for: path.id))
                        .font(.title3)
                        .foregroundStyle(tint)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Lernstrecke \(accentIndex + 1)")
                        .font(AppFont.germanCaption().weight(.bold))
                        .foregroundStyle(tint)
                    Text(path.title)
                        .font(AppFont.germanBody().weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(path.objective)
                        .font(AppFont.germanCaption())
                        .foregroundStyle(ColorTokens.textSecondary)

                    PathProgressBar(states: PilotPathProgressTracker.stepDotStates(path: path, progress: progress))
                        .padding(.vertical, Spacing.xxs)

                    statusPill(path: path, progress: progress, isComplete: isComplete, isNext: isNext, tint: tint)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .strokeBorder(isNext ? ColorTokens.primary : .clear, lineWidth: 1.5)
        )
    }

    private func statusPill(
        path: PilotLearningPath,
        progress: PilotLearningPathProgress,
        isComplete: Bool,
        isNext: Bool,
        tint: Color
    ) -> some View {
        let label: String
        let systemImage: String?
        let filled: Bool

        if isComplete {
            label = "Abgeschlossen"
            systemImage = "checkmark"
            filled = false
        } else if !progress.completedStepIDs.isEmpty {
            label = "Fortsetzen"
            systemImage = "play.fill"
            filled = isNext
        } else if isNext {
            label = "Starten"
            systemImage = "play.fill"
            filled = true
        } else {
            label = "Noch nicht begonnen"
            systemImage = nil
            filled = false
        }

        return HStack(spacing: Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(label)
        }
        .font(AppFont.germanCaption().weight(.bold))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .foregroundStyle(filled ? .white : (isComplete ? tint : ColorTokens.textSecondary))
        .background(filled ? tint : (isComplete ? tint.opacity(0.14) : ColorTokens.background))
        .clipShape(Capsule())
    }

    private var furtherCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink { GrammarView() } label: {
                    furtherRow(title: "Grammatiknachschlagewerk", systemImage: "text.book.closed")
                }
                .buttonStyle(.plain)
                Divider().overlay(ColorTokens.divider)
                NavigationLink { ReviewView() } label: {
                    furtherRow(title: "Wiederholung", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func furtherRow(title: String, systemImage: String) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Spacing.xxs, style: .continuous)
                    .fill(ColorTokens.background)
                Image(systemName: systemImage)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(width: 34, height: 34)

            Text(title)
                .font(AppFont.germanBody().weight(.semibold))
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer(minLength: Spacing.xxs)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary.opacity(0.6))
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: HitTarget.minimum)
    }

    private func chapterIcon(for pathID: String) -> String {
        switch pathID {
        case PilotLearningPathCatalog.vorstellen.id: "hand.wave.fill"
        case PilotLearningPathCatalog.cafe.id: "cup.and.saucer.fill"
        default: "book.fill"
        }
    }

    private var nextIncompletePathID: String? {
        let paths = PilotLearningPathCatalog.all
        let progress = paths.map { progressByPathID[$0.id] ?? PilotLearningPathProgress(pathID: $0.id) }
        return PilotPathProgressTracker.nextIncompletePath(paths: paths, progress: progress)?.id
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
