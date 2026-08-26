import Foundation
import Testing
@testable import TheHorde

@Suite("Effort evaluation")
struct EffortEvaluationTests {
    @Test func suppliedEffortMapsDirectlyWithoutModelAttemptOrLog() async throws {
        let probe = EffortProbe(response: 3)
        let logger = CapturingAttemptLogger()
        let client = FoundationModelClient(
            attemptLogger: logger,
            effortResponseOverride: { instructions, prompt in
                try await probe.respond(instructions: instructions, prompt: prompt)
            }
        )

        for (supplied, expected) in [(GoalEffort.small, EffortRating.one), (.medium, .two), (.large, .three)] {
            let result = try await client.evaluateEffort(
                event: event(id: supplied.rawValue, effort: supplied),
                history: history()
            )
            #expect(result.effort == ResolutionEffort(rating: expected, source: .userSelected))
            #expect(result.comparisonHistoryIDs.isEmpty)
            #expect(result.promptVersion == nil)
        }

        #expect(await probe.responseCount == 0)
        #expect(await logger.snapshot().isEmpty)
    }

    @Test func omittedEffortMakesOneLoggedAttemptWithGoalHistoryAndRatingRules() async throws {
        let probe = EffortProbe(response: 3)
        let logger = CapturingAttemptLogger()
        let client = FoundationModelClient(
            attemptLogger: logger,
            effortResponseOverride: { instructions, prompt in
                try await probe.respond(instructions: instructions, prompt: prompt)
            }
        )
        let comparisons = history()

        let result = try await client.evaluateEffort(
            event: event(id: "estimated", title: "Climb the black ridge", notes: "Reach the summit", valence: .positive),
            history: comparisons
        )

        #expect(result.effort == ResolutionEffort(rating: .three, source: .modelEstimated))
        #expect(result.comparisonHistoryIDs == comparisons.map(\.id))
        #expect(result.promptVersion == EffortModelContract.promptVersion)
        #expect(await probe.responseCount == 1)
        let request = await probe.lastRequest
        #expect(request?.instructions.localizedCaseInsensitiveContains("routine attempts lower") == true)
        #expect(request?.instructions.localizedCaseInsensitiveContains("similar prior attempts failed") == true)
        #expect(request?.prompt.contains("Climb the black ridge\nReach the summit") == true)
        #expect(request?.prompt.contains("CURRENT OUTCOME passed") == true)
        #expect(request?.prompt.contains("outcome=failed") == true)
        #expect(request?.prompt.contains("Missed comparison 0") == true)

        let logs = await logger.snapshot()
        #expect(logs.count == 1)
        #expect(logs.first?.stage == .effortEvaluation)
        #expect(logs.first?.attempt == 1)
        #expect(logs.first?.outcome == .succeeded)
        #expect(logs.first?.instructionsText == request?.instructions)
        #expect(logs.first?.promptText == request?.prompt)
        #expect(logs.first?.requestText?.isEmpty == false)
        #expect(logs.first?.responseText == "{\"rating\":3}")
    }

    @Test func malformedRatingIsLoggedOnceAndCannotAdvanceOrPersist() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Cross the ash field"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let (pending, _) = try await store.claimEvent(eventID)
        let probe = EffortProbe(response: 4)
        let logger = CapturingAttemptLogger()
        let client = FoundationModelClient(
            attemptLogger: logger,
            effortResponseOverride: { instructions, prompt in
                try await probe.respond(instructions: instructions, prompt: prompt)
            }
        )

        await #expect(throws: ModelClientError.self) {
            let result = try await client.evaluateEffort(event: pending, history: [])
            try await store.checkpointEffort(eventID: eventID, result: result)
        }

        let unchanged = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(unchanged.effort == nil)
        #expect(unchanged.resolutionState?.stage == .effortSelection)
        #expect(unchanged.resolutionState?.effort == nil)
        #expect(await probe.responseCount == 1)
        let logs = await logger.snapshot()
        #expect(logs.count == 1)
        #expect(logs.first?.outcome == .failed)
        #expect(logs.first?.stage == .effortEvaluation)
    }

    @Test func historyTrimsOneAtATimeAndOverflowNeverCallsResponder() async throws {
        let probe = EffortProbe(response: 2, fitsAtOrBelow: -1)
        let logger = CapturingAttemptLogger()
        let client = FoundationModelClient(
            attemptLogger: logger,
            effortResponseOverride: { instructions, prompt in
                try await probe.respond(instructions: instructions, prompt: prompt)
            },
            effortContextFitOverride: { candidate in await probe.fits(candidate) }
        )

        await #expect(throws: ModelClientError.self) {
            _ = try await client.evaluateEffort(event: event(id: "overflow"), history: history())
        }

        #expect(await probe.fitCounts == Array(stride(from: 10, through: 0, by: -1)))
        #expect(await probe.responseCount == 0)
        let logs = await logger.snapshot()
        #expect(logs.count == 1)
        #expect(logs.first?.outcome == .failed)
        #expect(logs.first?.errorText?.contains("contextOverflow") == true)
    }

    @Test func fittedHistoryCallsModelOnceAndPersistsExactlyTheFirstSevenIDs() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Survey the ruined pass"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let (pending, _) = try await store.claimEvent(eventID)
        let probe = EffortProbe(response: 2, fitsAtOrBelow: 7)
        let client = FoundationModelClient(
            attemptLogger: CapturingAttemptLogger(),
            effortResponseOverride: { instructions, prompt in
                try await probe.respond(instructions: instructions, prompt: prompt)
            },
            effortContextFitOverride: { candidate in await probe.fits(candidate) }
        )

        let result = try await client.evaluateEffort(event: pending, history: history())
        try await store.checkpointEffort(eventID: eventID, result: result)

        #expect(await probe.fitCounts == [10, 9, 8, 7])
        #expect(await probe.responseCount == 1)
        #expect(result.comparisonHistoryIDs == (0..<7).map { "comparison-\($0)" })
        #expect(await probe.lastRequest?.prompt.contains("comparison-6") == true)
        #expect(await probe.lastRequest?.prompt.contains("comparison-7") == false)
        let persisted = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(persisted.effort == ResolutionEffort(rating: .two, source: .modelEstimated))
        #expect(persisted.comparisonHistoryIDs == result.comparisonHistoryIDs)
        #expect(persisted.resolutionState?.comparisonHistoryIDs == result.comparisonHistoryIDs)
    }

    @Test func checkpointPersistsExactlyOneRatingAndHistoryAcrossReopenAndGatesLaterStages() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde-v4.store")
        let eventID: String
        let result = EffortEvaluationResult(
            effort: ResolutionEffort(rating: .two, source: .modelEstimated),
            comparisonHistoryIDs: ["closest-failure", "closest-pass"],
            promptVersion: EffortModelContract.promptVersion
        )

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            let definitionID = try await store.createGoal(GoalDraft(title: "Raise the iron gate"))
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            try await store.completeOccurrence(id: occurrence.id)
            eventID = occurrence.id + ":positive"
            _ = try await store.claimEvent(eventID)
            await #expect(throws: StoreError.invalidResolutionState) {
                try await store.checkpointResolution(
                    eventID: eventID,
                    state: StagedResolutionState(stage: .effortSelection, effort: result.effort)
                )
            }
            try await store.checkpointEffort(eventID: eventID, result: result)
            try await store.checkpointEffort(eventID: eventID, result: result)
            let current = try await store.worldReadModel()
            let summary = "The gate remains staged, not committed."
            var stagedWorld = current.snapshot
            stagedWorld.rollingSummary = String((stagedWorld.rollingSummary + " " + summary).suffix(600))
            await #expect(throws: StoreError.invalidResolutionState) {
                try await store.stageFinalResolution(
                    eventID: eventID,
                    expectedRevision: current.revision,
                    world: stagedWorld,
                    mutations: [],
                    deltas: [],
                    generatedTitle: "The Iron Gate",
                    narration: "The iron gate rises over the empty cavern.",
                    summary: summary,
                    cue: .idle,
                    effort: ResolutionEffort(rating: .three, source: .modelEstimated),
                    comparisonHistoryIDs: result.comparisonHistoryIDs,
                    acceptedAction: "Raise iron gate",
                    promptVersions: ResolutionPromptVersions(effort: EffortModelContract.promptVersion)
                )
            }
            await #expect(throws: StoreError.invalidResolutionState) {
                try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
                    effort: ResolutionEffort(rating: .three, source: .modelEstimated),
                    comparisonHistoryIDs: result.comparisonHistoryIDs,
                    promptVersion: EffortModelContract.promptVersion
                ))
            }
            await #expect(throws: StoreError.invalidResolutionState) {
                try await store.checkpointResolution(
                    eventID: eventID,
                    state: StagedResolutionState(stage: .actionSuggestion, suggestedAction: "Raise iron gate")
                )
            }
            await #expect(throws: StoreError.invalidResolutionState) {
                try await store.checkpointResolution(
                    eventID: eventID,
                    state: StagedResolutionState(
                        stage: .actionSuggestion,
                        effort: ResolutionEffort(rating: .three, source: .modelEstimated),
                        comparisonHistoryIDs: result.comparisonHistoryIDs,
                        suggestedAction: "Raise iron gate",
                        promptVersions: ResolutionPromptVersions(effort: EffortModelContract.promptVersion)
                    )
                )
            }
            await #expect(throws: StoreError.invalidResolutionState) {
                try await store.checkpointResolution(
                    eventID: eventID,
                    state: StagedResolutionState(
                        stage: .actionSuggestion,
                        effort: result.effort,
                        comparisonHistoryIDs: ["different-history"],
                        suggestedAction: "Raise iron gate",
                        promptVersions: ResolutionPromptVersions(effort: EffortModelContract.promptVersion)
                    )
                )
            }
        }

        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await reopened.bootstrapForProof()
        let pending = try #require(await reopened.pendingStories().first { $0.id == eventID })
        #expect(pending.effort == result.effort)
        #expect(pending.comparisonHistoryIDs == result.comparisonHistoryIDs)
        #expect(pending.resolutionState?.effort == result.effort)
        #expect(pending.resolutionState?.comparisonHistoryIDs == result.comparisonHistoryIDs)
        #expect(pending.resolutionState?.promptVersions.effort == EffortModelContract.promptVersion)
        try await reopened.checkpointResolution(
            eventID: eventID,
            state: StagedResolutionState(
                stage: .actionSuggestion,
                effort: result.effort,
                comparisonHistoryIDs: result.comparisonHistoryIDs,
                suggestedAction: "Raise iron gate",
                promptVersions: ResolutionPromptVersions(effort: EffortModelContract.promptVersion)
            )
        )
    }

    private func event(
        id: String,
        title: String = "Complete the goal",
        notes: String = "Use the current details",
        effort: GoalEffort? = nil,
        valence: EventValence = .positive
    ) -> PendingStorySummary {
        PendingStorySummary(
            id: id,
            sourceTitle: title,
            sourceNotes: notes,
            sourceEffort: effort,
            valence: valence,
            status: .resolving,
            failureCode: nil,
            createdAt: .distantPast
        )
    }

    private func history() -> [AttemptedGoalContext] {
        (0..<10).map {
            AttemptedGoalContext(
                id: "comparison-\($0)",
                title: $0.isMultiple(of: 2) ? "Missed comparison \($0)" : "Passed comparison \($0)",
                notes: "Prior attempt details \($0)",
                outcome: $0.isMultiple(of: 2) ? .failed : .passed
            )
        }
    }
}

private actor CapturingAttemptLogger: ModelAttemptLogger {
    private var entries: [ModelDevLogEntry] = []

    func record(_ entry: ModelDevLogEntry) {
        entries.append(entry)
    }

    func snapshot() -> [ModelDevLogEntry] { entries }
}

private actor EffortProbe {
    struct Request: Sendable {
        let instructions: String
        let prompt: String
    }

    private let response: Int
    private let fitsAtOrBelow: Int?
    private(set) var responseCount = 0
    private(set) var fitCounts: [Int] = []
    private(set) var lastRequest: Request?

    init(response: Int, fitsAtOrBelow: Int? = nil) {
        self.response = response
        self.fitsAtOrBelow = fitsAtOrBelow
    }

    func respond(instructions: String, prompt: String) throws -> Int {
        responseCount += 1
        lastRequest = Request(instructions: instructions, prompt: prompt)
        return response
    }

    func fits(_ history: [AttemptedGoalContext]) -> Bool {
        fitCounts.append(history.count)
        return fitsAtOrBelow.map { history.count <= $0 } ?? true
    }
}
