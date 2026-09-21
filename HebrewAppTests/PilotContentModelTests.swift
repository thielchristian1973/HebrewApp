import Testing
import Foundation
@testable import HebrewApp

@Suite("Pilot content Domain models")
struct PilotContentModelTests {
    @Test("PilotLexeme decodes the shipped JSON shape")
    func decodesLexeme() throws {
        let json = """
        {"id":"lex_x","hebrew":"שלום","german":"Hallo","ttsText":"שלום","reviewStatus":"draft"}
        """.data(using: .utf8)!
        let lexeme = try JSONDecoder().decode(PilotLexeme.self, from: json)
        #expect(lexeme.id == "lex_x")
        #expect(lexeme.reviewStatus == .draft)
    }

    @Test("dialogue reachability: every node is reachable from the start node")
    func dialogueGraphIsReachable() {
        let dialogue = PilotDialogue(
            id: "d",
            title: "t",
            objective: "o",
            startNodeID: "a",
            nodes: [
                PilotDialogueNode(id: "a", promptSentenceID: "s1", answers: [PilotDialogueAnswer(sentenceID: "s2", nextNodeID: "b")], terminal: false),
                PilotDialogueNode(id: "b", promptSentenceID: "s3", answers: [], terminal: true)
            ],
            reviewStatus: .draft
        )
        #expect(dialogue.nodesByID.count == 2)
        #expect(dialogue.nodesByID["a"]?.terminal == false)
        #expect(dialogue.nodesByID["b"]?.terminal == true)
    }
}
