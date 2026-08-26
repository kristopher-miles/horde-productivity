import Foundation
import SpriteKit
import Testing
import UIKit
@testable import TheHorde

@Suite("Bounded model contract and product verification")
struct Phase6QualificationTests {
    @Test func authoredScenesAndEveryCueMapToShippingAssets() throws {
        let normal = try #require(ProductVerificationFixture.named("normal"))
        let hazard = try #require(ProductVerificationFixture.named("hazard"))
        let recovery = try #require(ProductVerificationFixture.named("recovery"))
        #expect(DungeonSceneView.assetName(world: normal.world, cue: .idle) == "DungeonNormal")
        #expect(DungeonSceneView.assetName(world: hazard.world, cue: .idle) == "DungeonHazard")
        #expect(DungeonSceneView.assetName(world: recovery.world, cue: .idle) == "DungeonRecovery")
        #expect(Set(AnimationCue.allCases.map { DungeonSceneView.assetName(world: normal.world, cue: $0) }) == ["DungeonNormal", "DungeonHazard", "DungeonRecovery"])
        for name in ["DungeonNormal", "DungeonHazard", "DungeonRecovery"] { #expect(UIImage(named: name) != nil) }
    }

    @Test func emberIdleAtlasMatchesPrototypeContract() {
        for (atlasName, names) in [("EmberIdle", DungeonSceneView.emberIdleFrameNames), ("EmberConcern", DungeonSceneView.emberConcernFrameNames)] {
            let atlas = SKTextureAtlas(named: atlasName)
            #expect(Set(atlas.textureNames) == Set(names))
            for name in names {
                let texture = atlas.textureNamed(name)
                #expect(texture.size().width.rounded() == DungeonSceneView.emberIdleFrameSize.width)
                #expect(texture.size().height.rounded() == DungeonSceneView.emberIdleFrameSize.height)
            }
        }
        #expect(DungeonSceneView.emberIdleFrameDuration == 0.18)
        #expect(DungeonSceneView.emberConcernFrameDuration == 0.14)
        #expect(DungeonSceneView.emberIdleScenePosition.x.rounded() == DungeonSceneView.emberIdleScenePosition.x)
        #expect(DungeonSceneView.emberIdleScenePosition.y.rounded() == DungeonSceneView.emberIdleScenePosition.y)
    }

    @Test @MainActor func emberIdleHonorsReducedMotionAndAppInterruption() throws {
        let world = try #require(ProductVerificationFixture.named("normal")?.world)
        let reduced = PixelDungeonScene(world: world, cue: .idle, reduceMotion: true)
        let reducedEmber = try #require(reduced.childNode(withName: "EmberPrototype") as? SKSpriteNode)
        #expect(reducedEmber.action(forKey: "idle") == nil)

        let animated = PixelDungeonScene(world: world, cue: .idle, reduceMotion: false)
        let animatedEmber = try #require(animated.childNode(withName: "EmberPrototype") as? SKSpriteNode)
        #expect(animatedEmber.action(forKey: "idle") != nil)
        #expect(animatedEmber.texture?.filteringMode == .nearest)
        let concerned = PixelDungeonScene(world: world, cue: .concern, reduceMotion: false)
        #expect(concerned.childNode(withName: "EmberPrototype")?.action(forKey: "concern") != nil)
        let reducedConcern = PixelDungeonScene(world: world, cue: .concern, reduceMotion: true)
        #expect(reducedConcern.childNode(withName: "EmberPrototype")?.action(forKey: "concern") == nil)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        #expect(animated.isPaused)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(!animated.isPaused)
    }

    @Test func showcaseDemonstratesOptionsAndDiverseStoryConsequences() throws {
        let showcase = try #require(ProductVerificationFixture.named("showcase"))
        #expect(Set(showcase.occurrences.compactMap(\.snapshot.category)) == [.work, .home, .personal])
        #expect(Set(showcase.occurrences.compactMap(\.snapshot.effort)) == [.small, .medium])
        #expect(showcase.occurrences.contains { if case .daily = $0.snapshot.recurrence { true } else { false } })
        #expect(showcase.occurrences.contains { if case .weekdays = $0.snapshot.recurrence { true } else { false } })
        #expect(Set(showcase.chronicle.map(\.valence)) == [.positive, .negative])
        #expect(Set(showcase.chronicle.map(\.cue)) == Set(AnimationCue.allCases))
        #expect(Set(showcase.chronicle.map(\.finalProse)).count == showcase.chronicle.count)
    }

    @Test func scalarToolArgumentsIgnoreGeneratedRecordPlaceholders() async throws {
        let arguments = StageMutationArguments(fieldID: "world.morale", operation: "increment", integerValue: 2, recordID: "unused", recordTitle: "unused", recordSummary: "unused", severityOrRank: 1, involvedEntityIDs: [])
        let stager = PatchStager()
        _ = try await stager.stage(arguments: arguments)
        let mutations = await stager.snapshot().0
        #expect(mutations == [.increment("world.morale", by: 2)])

        let world = WorldSnapshot.initial()
        let descriptors = WorldContract.descriptors(for: .negative, world: world)
        let setStager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        let setArguments = StageMutationArguments(fieldID: "world.morale", operation: "set", integerValue: 2, recordID: "unused", recordTitle: "unused", recordSummary: "unused", severityOrRank: 1, involvedEntityIDs: [])
        _ = try await setStager.stage(arguments: setArguments)
        let setSnapshot = await setStager.snapshot()
        #expect(setSnapshot.0 == [.increment("world.morale", by: -2)])
        #expect(setSnapshot.1.first?.operation == "set")
    }

    @Test func boundaryScalarStrengthIsConstrainedToAuthorizedNoOp() async throws {
        var world = WorldSnapshot.initial()
        world.morale = 0
        let descriptors = WorldContract.descriptors(for: .negative, world: world)
        let stager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        let arguments = StageMutationArguments(fieldID: "world.morale", operation: "increment", integerValue: 2, recordID: "unused", recordTitle: "unused", recordSummary: "unused", severityOrRank: 1, involvedEntityIDs: [])
        _ = try await stager.stage(arguments: arguments)
        let snapshot = await stager.snapshot()
        #expect(snapshot.0 == [.increment("world.morale", by: 0)])
        #expect(snapshot.1.first?.integerValue == 2)
        #expect(snapshot.1.first?.stagedIntegerValue == 0)
    }

    @Test func nearBoundaryScalarStrengthIsDirectionallyConstrained() async throws {
        var world = WorldSnapshot.initial()
        world.morale = 1
        let descriptors = WorldContract.descriptors(for: .negative, world: world)
        #expect(descriptors.first { $0.fieldID == "world.morale" }?.maxDelta == 1)
        let stager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        let arguments = StageMutationArguments(fieldID: "world.morale", operation: "increment", integerValue: 2, recordID: "unused", recordTitle: "unused", recordSummary: "unused", severityOrRank: 1, involvedEntityIDs: [])
        _ = try await stager.stage(arguments: arguments)
        let snapshot = await stager.snapshot()
        #expect(snapshot.0 == [.increment("world.morale", by: -1)])
        #expect(snapshot.1.first?.stagedIntegerValue == -1)
        let signedStager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        let signedArguments = StageMutationArguments(fieldID: "world.morale", operation: "increment", integerValue: -2, recordID: "unused", recordTitle: "unused", recordSummary: "unused", severityOrRank: 1, involvedEntityIDs: [])
        _ = try await signedStager.stage(arguments: signedArguments)
        let signedSnapshot = await signedStager.snapshot()
        #expect(signedSnapshot.0 == [.increment("world.morale", by: -1)])
        #expect(signedSnapshot.1.first?.integerValue == -2)
        #expect(signedSnapshot.1.first?.stagedIntegerValue == -1)
        #expect(throws: WorldPatchError.deltaExceeded("world.morale")) {
            _ = try WorldPatchValidator.applying([.increment("world.morale", by: 1)], to: world, valence: .negative, descriptors: descriptors)
        }
    }

    @Test func stagerRejectsInvalidCallWithoutContaminatingReceipt() async throws {
        var world = WorldSnapshot.initial()
        world.activeThreads = [ActiveThreadState(id: "existing-thread", title: "Existing", severity: 1, state: "active", involvedEntityIDs: ["dragon"], summary: "Existing thread.")]
        let descriptors = WorldContract.descriptors(for: .negative, world: world)
        let stager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        let invalid = StageMutationArguments(fieldID: "world.activeThreads", operation: "replace", integerValue: 0, recordID: "new-thread", recordTitle: "New", recordSummary: "Must not stage.", severityOrRank: 1, involvedEntityIDs: ["dragon"])
        await #expect(throws: WorldPatchError.invalidRecord("new-thread")) { _ = try await stager.stage(arguments: invalid) }
        let snapshot = await stager.snapshot()
        #expect(snapshot.0.isEmpty)
        #expect(snapshot.1.count == 1)
        #expect(snapshot.1.first?.accepted == false)
    }

    @Test func negativeThreadTextIsQualifiedBeforeValidation() async throws {
        let world = WorldSnapshot.initial()
        let descriptors = WorldContract.descriptors(for: .negative, world: world)
        let stager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        let arguments = StageMutationArguments(fieldID: "world.activeThreads", operation: "append", integerValue: 0, recordID: "minor-thread", recordTitle: "Morale Boost", recordSummary: "The residents restored calm.", severityOrRank: 1, involvedEntityIDs: ["dragon"])
        _ = try await stager.stage(arguments: arguments)
        let snapshot = await stager.snapshot()
        let record = snapshot.0.first?.record
        #expect(record?.title.localizedCaseInsensitiveContains("boost") == false)
        #expect(record?.summary.localizedCaseInsensitiveContains("calm") == false)
        #expect(record?.summary.localizedCaseInsensitiveContains("unsettled") == true)
        #expect(snapshot.1.first?.recordSummary == "The residents restored calm.")

        let titleOnlyMarker = StageMutationArguments(fieldID: "world.activeThreads", operation: "append", integerValue: 0, recordID: "title-only-thread", recordTitle: "Supply Concern", recordSummary: "The hallway remains quiet.", severityOrRank: 1, involvedEntityIDs: ["dragon"])
        let secondStager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        _ = try await secondStager.stage(arguments: titleOnlyMarker)
        let secondSnapshot = await secondStager.snapshot()
        let secondRecord = secondSnapshot.0.first?.record
        #expect(secondRecord?.summary.localizedCaseInsensitiveContains("threat") == true)
        #expect(secondRecord?.summary.localizedCaseInsensitiveContains("small") == false)
        #expect(secondRecord?.summary.localizedCaseInsensitiveContains("recoverable") == false)
    }

    @Test func consequentialThreatPassesQualificationAndWorldValidationUnsoftened() async throws {
        let world = WorldSnapshot.initial()
        let descriptors = WorldContract.descriptors(for: .negative, world: world)
        let stager = PatchStager(world: world, valence: .negative, descriptors: descriptors)
        let threat = "An enemy warband lays siege to the Empty Cavern and vows to seize it."
        let arguments = StageMutationArguments(fieldID: "world.activeThreads", operation: "append", integerValue: 0, recordID: "warband-siege", recordTitle: "Warband at the Gate", recordSummary: threat, severityOrRank: 2, involvedEntityIDs: ["dragon", "empty-cavern"])

        _ = try await stager.stage(arguments: arguments)
        let mutation = try #require(await stager.snapshot().0.first)
        #expect(mutation.record?.summary == threat)
        let applied = try WorldPatchValidator.applying([mutation], to: world, valence: .negative, descriptors: descriptors)
        #expect(applied.0.activeThreads.first?.summary == threat)

        let story = ModelStoryFields(title: "Warband at the Gate", narration: threat, summary: "Enemy warband threatens the cavern.", cue: "concern", receiptID: "receipt")
        let qualified = await FoundationModelClient().qualifiedNarrative(story, valence: .negative, sourceTitle: "Miss the watch")
        #expect(qualified.title == story.title)
        #expect(qualified.narration == story.narration)
        #expect(qualified.summary == story.summary)
    }

    @Test func unrecognizedThreatVocabularyFallsBackWithoutHarmlessPadding() async {
        let story = ModelStoryFields(title: "Black Banners", narration: "Black banners gather beyond the cavern mouth.", summary: "Armored foes mass beyond the boundary.", cue: "concern", receiptID: "receipt")
        let qualified = await FoundationModelClient().qualifiedNarrative(story, valence: .negative, sourceTitle: "Miss the watch")
        let text = "\(qualified.title) \(qualified.narration) \(qualified.summary)"

        #expect(text.localizedCaseInsensitiveContains("dangerous threat"))
        #expect(!text.localizedCaseInsensitiveContains("small"))
        #expect(!text.localizedCaseInsensitiveContains("recoverable"))
        #expect(!WorldPatchError.catastrophicNegative.localizedDescription.localizedCaseInsensitiveContains("recoverable"))
    }

    @Test func cannedDraftNarrationIsQualifiedForBothValences() async {
        let client = FoundationModelClient()
        let raw = ModelStoryFields(title: "Drafty Passage", narration: "A loose stone causes a mild draft.", summary: "A loose stone causes a mild draft.", cue: "resourceChanges", receiptID: "receipt")

        let positive = await client.qualifiedNarrative(raw, valence: .positive, sourceTitle: "File the tax return")
        #expect(positive.narration.localizedCaseInsensitiveContains("draft") == false)
        #expect(positive.narration.localizedCaseInsensitiveContains("tax return") == true)
        #expect(positive.narration.localizedCaseInsensitiveContains("kobold") == false)
        #expect(positive.summary.localizedCaseInsensitiveContains("benefit") == true)

        let negative = await client.qualifiedNarrative(raw, valence: .negative, sourceTitle: "Wash the dishes")
        #expect(negative.narration.localizedCaseInsensitiveContains("wash the dishes") == true)
        #expect(negative.narration.localizedCaseInsensitiveContains("dangerous threat") == true)
        #expect(negative.summary.localizedCaseInsensitiveContains("setback") == true)

        let expandingSummary = "A draft needs attention. " + String(repeating: "Care ", count: 25) + "repair."
        #expect(expandingSummary.count <= 160)
        let expanding = ModelStoryFields(title: "Draft", narration: "A small draft needs attention.", summary: expandingSummary, cue: "concern", receiptID: "receipt")
        let bounded = await client.qualifiedNarrative(expanding, valence: .negative, sourceTitle: "Wash the dishes")
        #expect(bounded.summary.count <= 160)
    }

    @Test func projectionPublishesConcreteCurrentBoundsAndPatchBudget() {
        var snapshot = WorldSnapshot.initial()
        snapshot.morale = 100
        let event = PendingStorySummary(id: "boundary", sourceTitle: "Finish the task", sourceNotes: "User data only", valence: .positive, status: .pending, failureCode: nil, createdAt: .distantPast)
        let descriptors = WorldContract.descriptors(for: .positive, world: snapshot)
        let projection = ProjectionBuilder.projection(event: event, world: WorldReadModel(dungeonName: "Vault", revision: 1, snapshot: snapshot), descriptors: descriptors)
        #expect(projection.contains("maximumMutations=4"))
        #expect(descriptors.first { $0.fieldID == "world.morale" }?.maxDelta == 0)
        #expect(projection.contains("legalStrength=0...0"))
        #expect(projection.contains("<user-notes>User data only</user-notes>"))
    }

    @Test func fullCollectionsStopAdvertisingImpossibleAppends() {
        var snapshot = WorldSnapshot.initial()
        snapshot.abilities = (0..<12).map { AbilityState(id: "ability-\($0)", name: "Ability \($0)", summary: "Fixture", rank: 1) }
        snapshot.activeThreads = (0..<4).map { ActiveThreadState(id: "thread-\($0)", title: "Thread \($0)", severity: 1, state: "active", involvedEntityIDs: ["dragon"], summary: "Fixture") }
        snapshot.facts = (0..<24).map { WorldFact(id: "fact-\($0)", title: "Fact \($0)", summary: "Fixture") }
        let descriptors = WorldContract.descriptors(for: .positive, world: snapshot)
        #expect(!descriptors.contains { $0.fieldID == "world.facts" })
        #expect(descriptors.first { $0.fieldID == "world.abilities" }?.operations == [.replace])
        #expect(descriptors.first { $0.fieldID == "world.activeThreads" }?.operations == [.replace])

        let initial = WorldContract.descriptors(for: .positive, world: .initial())
        #expect(initial.first { $0.fieldID == "world.abilities" }?.operations == [.append])
        #expect(initial.first { $0.fieldID == "world.activeThreads" }?.operations == [.append])
    }

    @Test func existingCollectionsPermitUpdatesBeforeTheyAreFullAndUseFullRanges() async throws {
        var snapshot = WorldSnapshot.initial()
        snapshot.abilities = [AbilityState(id: "ember-memory", name: "Ember Memory", summary: "Existing", rank: 1)]
        let descriptors = WorldContract.descriptors(for: .positive, world: snapshot)
        #expect(descriptors.first { $0.fieldID == "world.abilities" }?.operations == [.append, .replace])
        #expect(descriptors.first { $0.fieldID == "world.abilities" }?.range == 1...3)
        #expect(descriptors.first { $0.fieldID == "world.activeThreads" }?.range == 1...4)

        let stager = PatchStager(world: snapshot, valence: .positive, descriptors: descriptors)
        let arguments = StageMutationArguments(fieldID: "world.abilities", operation: "replace", integerValue: 0, recordID: "ember-memory", recordTitle: "Ember Memory", recordSummary: "The practiced memory grows clearer.", severityOrRank: 3, involvedEntityIDs: [])
        _ = try await stager.stage(arguments: arguments)
        #expect(await stager.snapshot().0.first?.record?.severityOrRank == 3)
    }

    @Test func onDiskStoreSurvivesTrueReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde.store")
        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            _ = try await store.prepareAppState()
            try await store.completeOnboarding(dragonName: "Ember", dungeonName: "The Cinder Vault")
            let id = try await store.createGoal(GoalDraft(title: "Persist me"), now: Date(timeIntervalSince1970: 10))
            let occurrence = try #require(await store.definitionSummary(id: id)?.history.first)
            try await store.completeOccurrence(id: occurrence.id, now: Date(timeIntervalSince1970: 11))
        }
        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await reopened.bootstrapForProof()
        #expect(try await reopened.pendingStoryCount() == 1)
        #expect(try await reopened.occurrenceSummaries().first?.state == .completed)
    }

}
