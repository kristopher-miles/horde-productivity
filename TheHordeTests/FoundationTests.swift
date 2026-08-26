import Foundation
import SwiftData
import Testing
@testable import TheHorde

@Suite("Foundation and platform proof")
struct FoundationTests {
    @Test func validatorRejectsUnauthorizedAndOutOfRangeMutations() throws {
        let descriptors = HordeStore.proofDescriptors
        #expect(throws: PatchValidationError.unknownField("hidden.gold")) {
            try PatchValidator.validate([StagedMutation(fieldID: "hidden.gold", operation: .increment, value: 1)], descriptors: descriptors, currentValues: [:], maximumCount: 4)
        }
        #expect(throws: PatchValidationError.deltaExceeded("world.morale")) {
            try PatchValidator.validate([StagedMutation(fieldID: "world.morale", operation: .increment, value: 50)], descriptors: descriptors, currentValues: ["world.morale": 50], maximumCount: 4)
        }
    }

    @Test func transactionCommitsAllRelatedRecords() async throws {
        let container = try HordeStore.makeContainer(inMemory: true)
        let store = HordeStore(modelContainer: container)
        try await store.insertProofEvent()
        try await store.commitProof(eventID: "proof-event", mutations: [StagedMutation(fieldID: "world.morale", operation: .increment, value: 2)], title: "A Brighter Vault", narration: "The finished work hardens Ember’s resolve.", summary: "Morale rose.")
        let snapshot = try await store.proofSnapshot(eventID: "proof-event")
        #expect(snapshot.revision == 1)
        #expect(snapshot.status == EventStatus.resolved.rawValue)
        #expect(snapshot.chronicleCount == 1)
    }

    @Test func transactionRollsBackOnFailure() async throws {
        let container = try HordeStore.makeContainer(inMemory: true)
        let store = HordeStore(modelContainer: container)
        try await store.insertProofEvent()
        await #expect(throws: StoreError.injectedFailure) {
            try await store.commitProof(eventID: "proof-event", mutations: [StagedMutation(fieldID: "world.food", operation: .increment, value: 2)], title: "Stored Provisions", narration: "A shelf fills.", summary: "Food rose.", failBeforeSave: true)
        }
        let snapshot = try await store.proofSnapshot(eventID: "proof-event")
        #expect(snapshot.revision == 0)
        #expect(snapshot.status == EventStatus.pending.rawValue)
        #expect(snapshot.chronicleCount == 0)
    }
}
