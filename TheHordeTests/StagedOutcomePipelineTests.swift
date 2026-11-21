import Foundation
import Testing
@testable import TheHorde

@Suite("Staged outcome pipeline")
struct StagedOutcomePipelineTests {
    enum SourceOutcome: CaseIterable, Equatable, Sendable {
        case completed, expired, failed

        var occurrenceState: GoalOccurrenceState {
            switch self {
            case .completed: .completed
            case .expired: .expired
            case .failed: .failed
            }
        }

        var valence: EventValence { self == .completed ? .positive : .negative }
        var promptLabel: String {
            switch self {
            case .completed: "completed success"
            case .expired: "expired failure"
            case .failed: "declared failure"
            }
        }
        var historyOutcome: AttemptedGoalOutcome { self == .completed ? .passed : .failed }
    }

    enum ActionBranch: CaseIterable, Equatable, Sendable { case suggested, custom }

    @Test func everyOutcomeRunsSuggestedAndCustomStagingWithoutDuplicateEventsOrWorldCommit() async throws {
        for source in SourceOutcome.allCases {
            for branch in ActionBranch.allCases {
                let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
                try await store.bootstrapForProof()
                let base = Date(timeIntervalSince1970: 1_800_000_000)
                var draft = GoalDraft(
                    title: "Hold the " + source.promptLabel + " gate",
                    dueDate: source == .expired ? base.addingTimeInterval(10) : nil,
                    includesTime: source == .expired
                )
                draft.effort = .large
                let definitionID = try await store.createGoal(draft, now: base)
                let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)

                switch source {
                case .completed:
                    _ = try await store.completeOccurrence(id: occurrence.id, now: base.addingTimeInterval(20))
                    _ = try await store.completeOccurrence(id: occurrence.id, now: base.addingTimeInterval(21))
                case .expired:
                    #expect(try await store.reconcileDeadlines(now: base.addingTimeInterval(20)) == 1)
                    #expect(try await store.reconcileDeadlines(now: base.addingTimeInterval(21)) == 0)
                case .failed:
                    _ = try await store.failOccurrence(id: occurrence.id, now: base.addingTimeInterval(20))
                    _ = try await store.failOccurrence(id: occurrence.id, now: base.addingTimeInterval(21))
                }

                let eventID = occurrence.id + ":" + source.valence.rawValue
                let resolvedOccurrence = try #require(await store.occurrenceSummaries().first { $0.id == occurrence.id })
                #expect(resolvedOccurrence.state == source.occurrenceState)
                let initialEvents = try await store.allStoryEvents()
                #expect(initialEvents.count == 1)
                #expect(initialEvents.first?.id == eventID)
                #expect(initialEvents.first?.valence == source.valence)
                #expect(initialEvents.first?.status == .pending)
                #expect(initialEvents.first?.sourceOutcome == source.occurrenceState)
                let history = AttemptedGoalHistory.closest(
                    to: draft.title,
                    currentOccurrenceID: "different-occurrence",
                    among: [resolvedOccurrence],
                    distance: { _, _ in 0 }
                )
                #expect(history.first?.outcome == source.historyOutcome)

                let originalWorld = try await store.worldReadModel()
                let logger = OutcomeLogCapture()
                let finalProse = Self.paragraph(for: source)
                let client = FoundationModelClient(
                    attemptLogger: logger,
                    effortResponseOverride: { _, _ in
                        Issue.record("A supplied effort must not call the effort model")
                        return 1
                    },
                    suggestionResponseOverride: { _, prompt in
                        #expect(prompt.contains("CURRENT OUTCOME \(source.promptLabel)"))
                        return source == .completed ? "Claim the ember standard" : "Face the gathering ruin"
                    },
                    customActionResponseOverride: { _, prompt in
                        #expect(prompt.contains("CURRENT OUTCOME \(source.promptLabel)"))
                        return CustomActionModelResponse(action: "Defend the broken threshold")
                    },
                    finalProseResponseOverride: { _, prompt in
                        #expect(prompt.contains("CURRENT OUTCOME \(source.promptLabel)"))
                        return finalProse
                    },
                    compatibilityOverride: .available
                )
                let coordinator = ResolutionCoordinator(store: store, model: client)

                guard case .suggested(let suggestion) = await coordinator.suggestAction(eventID: eventID) else {
                    Issue.record("Suggestion staging failed for \(source)")
                    continue
                }
                var staged = try #require(await store.pendingStories().first { $0.id == eventID }.flatMap(\.resolutionState))
                let acceptedAction: String
                switch branch {
                case .suggested:
                    acceptedAction = suggestion
                case .custom:
                    guard case .interpreted(let interpretation) = await coordinator.interpretCustomAction(
                        eventID: eventID,
                        customAction: "Defend the threshold despite the breach"
                    ) else {
                        Issue.record("Custom-action staging failed for \(source)")
                        continue
                    }
                    acceptedAction = interpretation
                    staged = try #require(await store.pendingStories().first { $0.id == eventID }.flatMap(\.resolutionState))
                }

                staged.stage = .actionAccepted
                staged.acceptedAction = acceptedAction
                try await store.checkpointResolution(eventID: eventID, state: staged)
                #expect(await coordinator.generateFinalProse(eventID: eventID) == .generated(finalProse))

                let finalEvent = try #require(await store.pendingStories().first { $0.id == eventID })
                #expect(finalEvent.sourceEffort == .large)
                #expect(finalEvent.sourceOutcome == source.occurrenceState)
                #expect(finalEvent.resolutionState?.effort == ResolutionEffort(rating: .three, source: .userSelected))
                #expect(finalEvent.resolutionState?.promptVersions.effort == nil)
                #expect(finalEvent.resolutionState?.stage == .finalProse)
                #expect(finalEvent.resolutionState?.finalProse == finalProse)
                #expect(try await store.worldReadModel() == originalWorld)
                #expect(try await store.chronicle().isEmpty)
                #expect(try await store.allStoryEvents().count == 1)

                let logs = await logger.snapshot()
                let expectedStages: [ModelRequestStageID] = branch == .suggested
                    ? [.actionSuggestion, .finalProse]
                    : [.actionSuggestion, .customActionInterpretation, .finalProse]
                #expect(logs.map(\.stage) == expectedStages)
                #expect(logs.allSatisfy { $0.outcome == .succeeded })
                #expect(logs.allSatisfy { $0.promptText.contains("CURRENT OUTCOME \(source.promptLabel)") })
                #expect(logs.last?.responseText?.contains(finalProse) == true)

                let projection = ProjectionBuilder.projection(
                    event: finalEvent,
                    world: originalWorld,
                    descriptors: WorldContract.descriptors(for: source.valence, effort: finalEvent.effort, world: originalWorld.snapshot)
                )
                let legacyPrompt = HordeModelContract.prompt(projection: projection, valence: source.valence)
                #expect(projection.contains("outcome=\(source.promptLabel)"))
                #expect(legacyPrompt.contains(source == .completed ? "OUTCOME IS A COMPLETED GOAL" : "OUTCOME IS AN EXPIRED OR EXPLICITLY FAILED GOAL"))
            }
        }
    }

    private static func paragraph(for outcome: SourceOutcome) -> String {
        let opening = switch outcome {
        case .completed: "The completed victory crowns the dragon's defense"
        case .expired: "The expired duty ends in ruin and loss"
        case .failed: "The declared failure opens a dangerous breach"
        }
        let words = opening.split(separator: " ").map(String.init)
        return (words + Array(repeating: "embers", count: 60 - words.count)).joined(separator: " ")
    }
}

private actor OutcomeLogCapture: ModelAttemptLogger {
    private var entries: [ModelDevLogEntry] = []

    func record(_ entry: ModelDevLogEntry) { entries.append(entry) }
    func snapshot() -> [ModelDevLogEntry] { entries }
}
