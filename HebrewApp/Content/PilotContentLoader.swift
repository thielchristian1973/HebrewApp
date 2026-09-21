import Foundation
import CryptoKit

/// Loads Content/Pilot's manifest + fixtures from the app bundle, verifies SHA-256 hashes and
/// declared counts against the manifest (mirroring Scripts/validate_pilot.py so the same
/// invariants are enforced both at CI/build time and at app runtime), and decodes them into
/// Domain value types. Never mutates the loaded content — the bundle is the sole immutable
/// source of course data at this stage (ARCHITECTURE.md).
///
/// The repo-level source folder is `Content/Pilot/`, but a folder reference in the Xcode
/// project keeps only its own name at the bundle root — so at runtime the files live under
/// `HebrewApp.app/Pilot/`, not `HebrewApp.app/Content/Pilot/`. `subdirectory` reflects that.
struct PilotContentLoader: ContentRepository {
    private let bundle: Bundle
    private let subdirectory: String

    init(bundle: Bundle = .main, subdirectory: String = "Pilot") {
        self.bundle = bundle
        self.subdirectory = subdirectory
    }

    func loadPilotBundle() async throws(ContentLoadError) -> PilotContentBundle {
        let manifest: PilotManifest = try decode(fileName: "manifest.json", as: PilotManifest.self)

        guard manifest.schemaVersion == 1 else {
            throw ContentLoadError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        for file in manifest.files {
            try verifyHash(fileName: file.path, expectedSHA256: file.sha256)
        }

        let lexemes: [PilotLexeme] = try decode(fileName: "lexemes.json", as: [PilotLexeme].self)
        let sentences: [PilotSentence] = try decode(fileName: "sentences.json", as: [PilotSentence].self)
        let dialogues: [PilotDialogue] = try decode(fileName: "dialogues.json", as: [PilotDialogue].self)

        try requireCount(lexemes.count, expected: manifest.counts.lexemes, kind: "lexemes")
        try requireCount(sentences.count, expected: manifest.counts.sentences, kind: "sentences")
        try requireCount(dialogues.count, expected: manifest.counts.dialogues, kind: "dialogues")

        try requireUniqueIDs(lexemes.map(\.id) + sentences.map(\.id) + dialogues.map(\.id))

        return PilotContentBundle(manifest: manifest, lexemes: lexemes, sentences: sentences, dialogues: dialogues)
    }

    // MARK: - Helpers

    private func resourceURL(fileName: String) throws(ContentLoadError) -> URL {
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = bundle.url(
            forResource: nameWithoutExtension,
            withExtension: ext,
            subdirectory: subdirectory
        ) else {
            throw ContentLoadError.resourceNotFound(fileName)
        }
        return url
    }

    private func decode<T: Decodable>(fileName: String, as type: T.Type) throws(ContentLoadError) -> T {
        let url = try resourceURL(fileName: fileName)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentLoadError.resourceNotFound(fileName)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ContentLoadError.decodingFailed("\(fileName): \(error)")
        }
    }

    private func verifyHash(fileName: String, expectedSHA256: String) throws(ContentLoadError) {
        let url = try resourceURL(fileName: fileName)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentLoadError.resourceNotFound(fileName)
        }
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        guard hex == expectedSHA256 else {
            throw ContentLoadError.hashMismatch(file: fileName)
        }
    }

    private func requireCount(_ actual: Int, expected: Int, kind: String) throws(ContentLoadError) {
        guard actual == expected else {
            throw ContentLoadError.countMismatch(expected: expected, actual: actual, kind: kind)
        }
    }

    private func requireUniqueIDs(_ ids: [String]) throws(ContentLoadError) {
        var seen = Set<String>()
        for id in ids {
            guard seen.insert(id).inserted else {
                throw ContentLoadError.duplicateID(id)
            }
        }
    }
}
