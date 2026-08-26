import Foundation

enum ModelAttemptOutcome: String, Codable, Sendable {
    case succeeded
    case failed
}

struct ModelDevLogEntry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let timestamp: Date
    let eventID: String
    let goalTitle: String
    let stage: ModelRequestStageID
    let attempt: Int
    let outcome: ModelAttemptOutcome
    let instructionsText: String
    let promptText: String
    let requestText: String?
    let responseText: String?
    let responseMaterial: String?
    let attemptTranscript: String?
    let errorText: String?

    init(
        id: String = UUID().uuidString,
        timestamp: Date = .now,
        eventID: String,
        goalTitle: String,
        stage: ModelRequestStageID,
        attempt: Int,
        outcome: ModelAttemptOutcome,
        instructionsText: String,
        promptText: String,
        requestText: String?,
        responseText: String? = nil,
        responseMaterial: String? = nil,
        attemptTranscript: String? = nil,
        errorText: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventID = eventID
        self.goalTitle = goalTitle
        self.stage = stage
        self.attempt = attempt
        self.outcome = outcome
        self.instructionsText = instructionsText
        self.promptText = promptText
        self.requestText = requestText
        self.responseText = responseText
        self.responseMaterial = responseMaterial
        self.attemptTranscript = attemptTranscript
        self.errorText = errorText
    }
}

protocol ModelAttemptLogger: Sendable {
    func record(_ entry: ModelDevLogEntry) async
}

actor ModelDevLogStore: ModelAttemptLogger {
    static let maximumEntryCount = 10

    private let fileURL: URL
    private let isEnabled: @Sendable () -> Bool

    init(
        fileURL: URL = ModelDevLogStore.defaultFileURL,
        isEnabled: @escaping @Sendable () -> Bool = { DeveloperMode.isEnabled() }
    ) {
        self.fileURL = fileURL
        self.isEnabled = isEnabled
    }

    func record(_ entry: ModelDevLogEntry) async {
        guard isEnabled() else { return }
        var retained = loadEntries()
        retained.insert(entry, at: 0)
        if retained.count > Self.maximumEntryCount {
            retained.removeLast(retained.count - Self.maximumEntryCount)
        }
        try? persist(retained)
    }

    func entries() -> [ModelDevLogEntry] {
        guard isEnabled() else { return [] }
        return loadEntries()
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "The Horde", directoryHint: .isDirectory)
            .appending(path: "ModelDevLogs.json")
    }

    private func loadEntries() -> [ModelDevLogEntry] {
        (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([ModelDevLogEntry].self, from: $0) } ?? []
    }

    private func persist(_ entries: [ModelDevLogEntry]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    }
}
