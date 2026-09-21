import Testing
import Foundation
@testable import HebrewApp

@Suite("PilotContentLoader")
struct PilotContentLoaderTests {
    @Test("loads the real pilot bundle with matching manifest counts")
    func loadsRealBundle() async throws {
        let loader = PilotContentLoader(bundle: .main)
        let bundle = try await loader.loadPilotBundle()
        #expect(bundle.lexemes.count == 50)
        #expect(bundle.sentences.count == 20)
        #expect(bundle.dialogues.count == 4)
        #expect(bundle.manifest.status == "draft")
    }

    @Test("every lexeme and sentence is marked draft")
    func allDraft() async throws {
        let loader = PilotContentLoader(bundle: .main)
        let bundle = try await loader.loadPilotBundle()
        #expect(bundle.lexemes.allSatisfy { $0.reviewStatus == .draft })
        #expect(bundle.sentences.allSatisfy { $0.reviewStatus == .draft })
        #expect(bundle.dialogues.allSatisfy { $0.reviewStatus == .draft })
    }

    @Test("dialogue nodes only reference known sentence IDs")
    func dialogueReferencesAreValid() async throws {
        let loader = PilotContentLoader(bundle: .main)
        let bundle = try await loader.loadPilotBundle()
        let sentenceIDs = Set(bundle.sentences.map(\.id))
        for dialogue in bundle.dialogues {
            for node in dialogue.nodes {
                #expect(sentenceIDs.contains(node.promptSentenceID))
                for answer in node.answers {
                    #expect(sentenceIDs.contains(answer.sentenceID))
                }
            }
        }
    }

    @Test("resource not found surfaces a typed error, never a crash")
    func missingResourceThrows() async {
        let loader = PilotContentLoader(bundle: Bundle(for: EmptyBundleMarker.self), subdirectory: "DoesNotExist")
        await #expect(throws: ContentLoadError.self) {
            _ = try await loader.loadPilotBundle()
        }
    }
}

private final class EmptyBundleMarker {}
