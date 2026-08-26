import Foundation
import Testing
@testable import TheHorde

@Suite("Model-selected consequence contract")
struct ConsequenceContractTests {
    @Test func effortOneTwoAndThreeAuthorizeVariedScalarEffectsWithoutChoosingAStat() throws {
        var original = WorldSnapshot.initial()
        original.morale = 50
        original.integrity = 50
        original.food = 50
        let cases: [(EffortRating, EventValence, String, Int)] = [
            (.one, .positive, "world.food", 4),
            (.two, .positive, "world.integrity", 8),
            (.three, .negative, "world.morale", -12)
        ]

        for (rating, valence, fieldID, delta) in cases {
            let effort = ResolutionEffort(rating: rating, source: .modelEstimated)
            let descriptors = WorldContract.descriptors(for: valence, effort: effort, world: original)
            let scalarFields = Set(descriptors.filter { $0.kind == .integer }.map(\.fieldID))
            #expect(Set(["world.morale", "world.integrity", "world.food"]).isSubset(of: scalarFields))
            #expect(descriptors.first { $0.fieldID == fieldID }?.maxDelta == abs(delta))

            let (updated, changes) = try WorldPatchValidator.applying(
                [.increment(fieldID, by: delta)],
                to: original,
                valence: valence,
                descriptors: descriptors
            )
            #expect(changes.map(\.fieldID) == [fieldID])
            #expect(updated.hoard == original.hoard)
            switch fieldID {
            case "world.food": #expect(updated.food == original.food + delta)
            case "world.integrity": #expect(updated.integrity == original.integrity + delta)
            default: #expect(updated.morale == original.morale + delta)
            }
        }
    }

    @Test func bothOutcomesExposeTheSameAuthorizedFieldsAndPreserveReplacementDirection() throws {
        var world = WorldSnapshot.initial()
        world.abilities = [AbilityState(id: "ember-sight", name: "Ember Sight", summary: "An established ability.", rank: 2)]
        world.activeThreads = [ActiveThreadState(id: "gate-threat", title: "Threat at the Gate", severity: 2, state: "active", involvedEntityIDs: ["dragon"], summary: "An established threat.")]
        let effort = ResolutionEffort(rating: .three, source: .userSelected)
        let positive = WorldContract.descriptors(for: .positive, effort: effort, world: world)
        let negative = WorldContract.descriptors(for: .negative, effort: effort, world: world)

        let sharedFields = Set([
            "world.morale", "world.integrity", "world.food",
            "world.abilities", "world.facts", "world.activeThreads"
        ])
        #expect(sharedFields.isSubset(of: Set(positive.map(\.fieldID))))
        #expect(sharedFields.isSubset(of: Set(negative.map(\.fieldID))))

        let strongerAbility = record(id: "ember-sight", title: "Far Ember Sight", value: 3)
        let weakerAbility = record(id: "ember-sight", title: "Faltering Ember Sight", value: 1)
        let quieterThreat = record(id: "gate-threat", title: "Fading Gate Threat", value: 1, involved: ["dragon"])
        let harsherThreat = record(id: "gate-threat", title: "War at the Gate", value: 4, involved: ["dragon"])

        let positiveWorld = try WorldPatchValidator.applying([
            mutation("world.abilities", .replace, strongerAbility),
            mutation("world.activeThreads", .replace, quieterThreat)
        ], to: world, valence: .positive, descriptors: positive).0
        #expect(positiveWorld.abilities.first?.rank == 3)
        #expect(positiveWorld.activeThreads.first?.severity == 1)

        let negativeWorld = try WorldPatchValidator.applying([
            mutation("world.abilities", .replace, weakerAbility),
            mutation("world.activeThreads", .replace, harsherThreat)
        ], to: world, valence: .negative, descriptors: negative).0
        #expect(negativeWorld.abilities.first?.rank == 1)
        #expect(negativeWorld.activeThreads.first?.severity == 4)

        #expect(throws: WorldPatchError.deltaExceeded("world.abilities")) {
            _ = try WorldPatchValidator.applying([mutation("world.abilities", .replace, weakerAbility)], to: world, valence: .positive, descriptors: positive)
        }
        #expect(throws: WorldPatchError.deltaExceeded("world.activeThreads")) {
            _ = try WorldPatchValidator.applying([mutation("world.activeThreads", .replace, quieterThreat)], to: world, valence: .negative, descriptors: negative)
        }
    }

    @Test func collectionAndEntityConsequencesRemainStrictlyValidated() throws {
        var world = WorldSnapshot.initial()
        world.morale = 50
        world.abilities = [AbilityState(id: "ember-sight", name: "Ember Sight", summary: "An established ability.", rank: 3)]
        let effort = ResolutionEffort(rating: .three, source: .modelEstimated)
        let descriptors = WorldContract.descriptors(for: .negative, effort: effort, world: world)
        let lastingFact = record(id: "scarred-gate", title: "The Scarred Gate", value: nil)
        let threat = record(id: "ash-warband", title: "The Ash Warband", value: 4, involved: ["dragon", "empty-cavern"])
        let weakenedAbility = record(id: "ember-sight", title: "Clouded Ember Sight", value: 1)

        let (updated, changes) = try WorldPatchValidator.applying([
            .increment("world.morale", by: -12),
            mutation("world.abilities", .replace, weakenedAbility),
            .append("world.facts", record: lastingFact),
            .append("world.activeThreads", record: threat)
        ], to: world, valence: .negative, descriptors: descriptors)
        #expect(updated.morale == 38)
        #expect(updated.abilities.first?.rank == 1)
        #expect(updated.facts.last?.id == "scarred-gate")
        #expect(updated.activeThreads.last?.severity == 4)
        #expect(Set(changes.map(\.fieldID)) == ["world.morale", "world.abilities", "world.facts", "world.activeThreads"])

        let invalidReference = record(id: "unbound-threat", title: "Unbound Threat", value: 4, involved: ["not-in-the-save"])
        #expect(throws: WorldPatchError.invalidReference("unbound-threat")) {
            _ = try WorldPatchValidator.applying([.append("world.activeThreads", record: invalidReference)], to: world, valence: .negative, descriptors: descriptors)
        }
        #expect(throws: WorldPatchError.unknownField("hidden.gold")) {
            _ = try WorldPatchValidator.applying([.increment("hidden.gold", by: -1)], to: world, valence: .negative, descriptors: descriptors)
        }
        #expect(world.morale == 50)
        #expect(world.activeThreads.isEmpty)
    }

    @Test func worldAwareContractDoesNotAdvertiseImpossibleReplacements() {
        var world = WorldSnapshot.initial()
        world.abilities = [AbilityState(id: "spent-sight", name: "Spent Sight", summary: "Already at the lower bound.", rank: 1)]
        world.activeThreads = [ActiveThreadState(id: "dire-threat", title: "Dire Threat", severity: 2, state: "active", involvedEntityIDs: ["dragon"], summary: "Already at this effort's upper bound.")]
        let effort = ResolutionEffort(rating: .one, source: .modelEstimated)

        let negative = WorldContract.descriptors(for: .negative, effort: effort, world: world)
        #expect(!negative.contains { $0.fieldID == "world.abilities" })
        #expect(negative.first { $0.fieldID == "world.activeThreads" }?.operations == [.append])

        world.abilities[0].rank = 3
        world.activeThreads[0].severity = 1
        let positive = WorldContract.descriptors(for: .positive, effort: effort, world: world)
        #expect(positive.first { $0.fieldID == "world.abilities" }?.operations == [.append])
        #expect(positive.first { $0.fieldID == "world.activeThreads" }?.operations == [.append])
    }

    @Test func modelToolCanStageTheFullAuthorizedEffortThreeLoss() async throws {
        var world = WorldSnapshot.initial()
        world.morale = 50
        let effort = ResolutionEffort(rating: .three, source: .modelEstimated)
        let descriptors = WorldContract.descriptors(for: .negative, effort: effort, world: world)
        let stager = PatchStager(world: world, valence: .negative, descriptors: descriptors)

        _ = try await stager.stage(arguments: StageMutationArguments(
            fieldID: "world.morale",
            operation: "increment",
            integerValue: 12,
            recordID: "unused",
            recordTitle: "unused",
            recordSummary: "unused",
            severityOrRank: 1,
            involvedEntityIDs: []
        ))

        #expect(await stager.snapshot().0 == [.increment("world.morale", by: -12)])
    }

    @Test func stagedStoreRevalidatesAgainstPersistedEffortAtomically() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Hold the cavern gate"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let (_, original) = try await store.claimEvent(eventID)
        let persistedEffort = ResolutionEffort(rating: .one, source: .userSelected)
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(effort: persistedEffort, comparisonHistoryIDs: [], promptVersion: nil))

        let mutation = WorldMutation.increment("world.morale", by: 8)
        let broadDescriptors = WorldContract.descriptors(for: .positive, effort: ResolutionEffort(rating: .three, source: .userSelected), world: original.snapshot)
        var (invalidWorld, invalidDeltas) = try WorldPatchValidator.applying([mutation], to: original.snapshot, valence: .positive, descriptors: broadDescriptors)
        let summary = "The gate changes the fate of the cavern."
        invalidWorld.rollingSummary = String((invalidWorld.rollingSummary + " " + summary).suffix(600))

        await #expect(throws: WorldPatchError.deltaExceeded("world.morale")) {
            try await store.stageFinalResolution(
                eventID: eventID,
                expectedRevision: original.revision,
                world: invalidWorld,
                mutations: [mutation],
                deltas: invalidDeltas,
                generatedTitle: "The Cavern Gate",
                narration: "The gate changes the fate of the cavern.",
                summary: summary,
                cue: .resourceChanges,
                effort: persistedEffort,
                acceptedAction: "Hold the cavern gate",
                promptVersions: ResolutionPromptVersions()
            )
        }
        #expect(try await store.worldReadModel() == original)
        #expect(try await store.chronicle().isEmpty)
        #expect(try await store.pendingStories().first { $0.id == eventID }?.resolutionState?.stage == .effortSelection)
    }

    @Test func projectionPublishesResolvedEffortAndAcceptedActionAsContext() {
        var event = PendingStorySummary(id: "context", sourceTitle: "Secure the eastern gate", sourceEffort: .small, valence: .positive, status: .resolving, failureCode: nil, createdAt: .distantPast)
        event.effort = ResolutionEffort(rating: .three, source: .modelEstimated)
        event.acceptedAction = "Bind the gate with dragonfire"
        let world = WorldReadModel(dungeonName: "The Vault", revision: 4, snapshot: .initial())
        let descriptors = WorldContract.descriptors(for: .positive, effort: event.effort, world: world.snapshot)
        let projection = ProjectionBuilder.projection(event: event, world: world, descriptors: descriptors)

        #expect(projection.contains("effort=3"))
        #expect(projection.contains("<accepted-action>Bind the gate with dragonfire</accepted-action>"))
        #expect(projection.contains("world.morale"))
        #expect(projection.contains("world.integrity"))
        #expect(projection.contains("world.food"))
    }

    private func record(id: String, title: String, value: Int?, involved: [String] = []) -> GeneratedRecord {
        GeneratedRecord(id: id, title: title, summary: "A consequence grounded in the accepted action.", severityOrRank: value, involvedEntityIDs: involved)
    }

    private func mutation(_ fieldID: String, _ operation: WorldMutationOperation, _ record: GeneratedRecord) -> WorldMutation {
        WorldMutation(fieldID: fieldID, operation: operation, integerValue: nil, record: record)
    }
}
