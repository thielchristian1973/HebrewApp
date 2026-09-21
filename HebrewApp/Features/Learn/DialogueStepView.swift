import SwiftUI

/// Drives one guided dialogue end to end: visible transcript, one choice at a time, a bounded
/// tutor hint, and the 3-strikes supported continuation
/// (Documentation/PRODUCT.md "Dialog"-Kernflow).
struct DialogueStepView: View {
    let dialogue: PilotDialogue
    let onFinished: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state: DialogueSessionState?
    @State private var isLoading = true
    @State private var hint: TutorSuggestion?
    @State private var isSpeaking = false

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Lade Dialog …")
            } else if let bundle = environment.contentBundle, let state, let engine = environment.makeDialogueEngine() {
                dialogueBody(state: state, bundle: bundle, engine: engine)
            } else {
                ErrorStateView(title: "Dialog nicht verfügbar", detail: dialogue.id)
            }
        }
        .navigationTitle(dialogue.title)
        .task { await load() }
    }

    private func dialogueBody(state: DialogueSessionState, bundle: PilotContentBundle, engine: DialogueEngine) -> some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: Spacing.md) {
                Text(dialogue.objective)
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(state.history) { turn in
                    if let prompt = bundle.sentencesByID[turn.promptSentenceID] {
                        HebrewGermanPair(hebrew: prompt.hebrew, german: prompt.german)
                    }
                    if let chosenID = turn.chosenSentenceID, let chosen = bundle.sentencesByID[chosenID] {
                        CardView {
                            HebrewGermanPair(hebrew: chosen.hebrew, german: chosen.german)
                        }
                    }
                }

                if state.isCompleted {
                    completedView
                } else if let node = dialogue.nodesByID[state.currentNodeID] {
                    currentPrompt(node: node, bundle: bundle)
                    choiceButtons(state: state, bundle: bundle, engine: engine)
                    hintButton(state: state, engine: engine)
                }
            }
            .padding(Spacing.md)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state.history.count)
        }
    }

    private func currentPrompt(node: PilotDialogueNode, bundle: PilotContentBundle) -> some View {
        Group {
            if let prompt = bundle.sentencesByID[node.promptSentenceID] {
                HebrewGermanPair(hebrew: prompt.hebrew, german: prompt.german)
            }
        }
    }

    private func choiceButtons(state: DialogueSessionState, bundle: PilotContentBundle, engine: DialogueEngine) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            ForEach(engine.choices(for: state, dialogue: dialogue)) { choice in
                if let sentence = bundle.sentencesByID[choice.sentenceID] {
                    Button {
                        Task { await submit(choice: choice, state: state, engine: engine) }
                    } label: {
                        HebrewText(sentence.hebrew, font: AppFont.hebrewBody())
                            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum, alignment: .trailing)
                    }
                    .buttonStyle(TactileButtonStyle())
                }
            }
        }
    }

    private func hintButton(state: DialogueSessionState, engine: DialogueEngine) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            if let hint, let sentenceID = hint.suggestedSentenceID, let bundle = environment.contentBundle,
               let sentence = bundle.sentencesByID[sentenceID] {
                StatusBadge(level: .notApplicable, text: "Tipp (\(hint.provider == .appleFoundationModel ? "Lokale KI" : "Geführt"))")
                Text(sentence.german)
                    .font(AppFont.germanCaption())
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            Button("Tipp anzeigen") {
                Task { await requestHint(state: state) }
            }
            .font(AppFont.germanCaption())
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var completedView: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Dialog abgeschlossen")
                .font(AppFont.sectionHeader())
            PrimaryButton("Weiter") {
                Task { await onFinished() }
            }
        }
        .padding(.top, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        let loaded = (try? await environment.progressRepository.loadDialogueSession(dialogueID: dialogue.id))
            ?? environment.makeDialogueEngine()?.startSession(for: dialogue)
        state = loaded
        isLoading = false
    }

    private func submit(choice: DialogueChoice, state currentState: DialogueSessionState, engine: DialogueEngine) async {
        hint = nil
        let outcome = engine.submit(choice: choice, state: currentState, dialogue: dialogue)
        await apply(outcome: outcome, itemID: currentState.currentNodeID, isAutoResolved: false)
    }

    private func requestHint(state currentState: DialogueSessionState) async {
        let provider = environment.makeAppleFoundationModelProviderIfAvailable() ?? environment.guidedDialogueProvider
        hint = try? await provider.suggestNextStep(for: currentState, dialogue: dialogue)
    }

    private func apply(outcome: DialogueStepOutcome, itemID: String, isAutoResolved: Bool) async {
        environment.feedback.play(FeedbackCueMapper.forDialogueOutcome(outcome, isAutoResolved: isAutoResolved))

        switch outcome {
        case .advanced(let newState), .completed(let newState):
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                state = newState
            }
            try? await environment.progressRepository.saveDialogueSession(newState)
            try? await environment.progressRepository.recordAttempt(
                PilotAttempt(timestampUTC: Date(), kind: .dialogueStep, itemID: itemID, correctness: .correct)
            )
        case .incorrectChoice(let newState, let revealAnswer):
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                state = newState
            }
            try? await environment.progressRepository.saveDialogueSession(newState)
            try? await environment.progressRepository.recordAttempt(
                PilotAttempt(timestampUTC: Date(), kind: .dialogueStep, itemID: itemID, correctness: .incorrect)
            )
            if revealAnswer, let engine = environment.makeDialogueEngine() {
                let revealed = engine.applySupportedContinuation(state: newState, dialogue: dialogue)
                await apply(outcome: revealed, itemID: itemID, isAutoResolved: true)
            }
        }
    }
}
