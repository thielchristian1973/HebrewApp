import SwiftUI

/// Plays one demo learning path end to end without requiring AI or a microphone
/// (Documentation/PILOT.md acceptance: "Beide Demo-Lernstrecken ohne KI und ohne Mikrofon
/// abschließbar"), and resumes correctly after a restart by reloading persisted step progress.
struct PilotPathPlayerView: View {
    let path: PilotLearningPath

    @Environment(AppEnvironment.self) private var environment
    @State private var progress: PilotLearningPathProgress?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Lade Fortschritt …")
            } else if let progress, let bundle = environment.contentBundle {
                content(progress: progress, bundle: bundle)
            } else if environment.contentBundle == nil {
                ErrorStateView(title: "Inhalte fehlen", detail: "Der Pilotinhalt konnte nicht geladen werden.")
            }
        }
        .navigationTitle(path.title)
        .task { await load() }
    }

    @ViewBuilder
    private func content(progress: PilotLearningPathProgress, bundle: PilotContentBundle) -> some View {
        if let step = PilotPathProgressTracker.nextIncompleteStep(path: path, progress: progress) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Schritt \(path.steps.firstIndex(where: { $0.id == step.id }).map { $0 + 1 } ?? 1) von \(path.steps.count)")
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
                    .padding(.horizontal, Spacing.md)

                stepView(step, bundle: bundle)
            }
            .padding(.top, Spacing.sm)
        } else {
            completionView
        }
    }

    @ViewBuilder
    private func stepView(_ step: PilotLearningStep, bundle: PilotContentBundle) -> some View {
        switch step.kind {
        case .vocabulary(let lexemeIDs):
            VocabularyStepView(
                lexemes: lexemeIDs.compactMap { bundle.lexemesByID[$0] },
                onFinished: { await completeStep(step.id) }
            )
        case .sentences(let sentenceIDs):
            SentenceStepView(
                sentences: sentenceIDs.compactMap { bundle.sentencesByID[$0] },
                onFinished: { await completeStep(step.id) }
            )
        case .dialogue(let dialogueID):
            if let dialogue = bundle.dialogue(id: dialogueID) {
                DialogueStepView(dialogue: dialogue, onFinished: { await completeStep(step.id) })
            } else {
                ErrorStateView(title: "Dialog fehlt", detail: dialogueID)
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(ColorTokens.primary)
            Text("\(path.title) abgeschlossen")
                .font(AppFont.sectionHeader())
            Text("Das ist eine Demo-Lernstrecke aus Pilotmaterial, keine vollständige A0-Lektion.")
                .font(AppFont.germanCaption())
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        let loaded = (try? await environment.progressRepository.loadPathProgress(pathID: path.id))
            ?? PilotLearningPathProgress(pathID: path.id)
        progress = loaded
        isLoading = false
    }

    private func completeStep(_ stepID: String) async {
        guard let current = progress else { return }
        let updated = PilotPathProgressTracker.completingStep(stepID, in: current, path: path)
        progress = updated
        try? await environment.progressRepository.savePathProgress(updated)
    }
}
