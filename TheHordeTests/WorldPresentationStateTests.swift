import Testing
@testable import TheHorde

@Suite("Empty and populated world presentation")
struct WorldPresentationStateTests {
    @Test func cleanWorldPresentsOneDragonOneLairAndNoEmptySections() throws {
        let world = WorldSnapshot.initial(dragonName: "Cinder")
        let state = WorldPresentationState(snapshot: world)

        #expect(state.isLoneDragon)
        #expect(state.populationSummary == "Cinder is alone in Empty Cavern.")
        #expect(state.lair?.id == "empty-cavern")
        #expect(state.discoveredPlaces.isEmpty)
        #expect(world.residents.isEmpty)
        #expect(world.facts.isEmpty)
        #expect(world.abilities.isEmpty)
        #expect(world.activeThreads.isEmpty)
    }

    @Test func populatedWorldProjectsEveryGrowingCollectionNormally() {
        var world = WorldSnapshot.initial(dragonName: "Cinder")
        world.residents = [CharacterState(
            id: "kobold", name: "Rill", role: "Scout", identity: "A scout.", vitality: 50, bond: 50, conditions: [],
            koboldVisual: KoboldVisualState(
                age: .kid,
                colors: CharacterPalette(
                    primary: RGBColor(red: 58, green: 107, blue: 190),
                    secondary: RGBColor(red: 145, green: 69, blue: 160)
                )
            )
        )]
        world.locations.append(LocationState(id: "depths", name: "Echoing Depths", status: "Discovered", summary: "A passage."))
        world.facts = [WorldFact(id: "mark", title: "Wyrm Mark", summary: "A sign.")]
        world.abilities = [AbilityState(id: "memory", name: "Ember Memory", summary: "A skill.", rank: 1)]
        world.activeThreads = [ActiveThreadState(id: "stalker", title: "Stone Stalker", severity: 2, state: "active", involvedEntityIDs: ["dragon", "kobold"], summary: "A threat.")]
        let state = WorldPresentationState(snapshot: world)

        #expect(!state.isLoneDragon)
        #expect(state.populationSummary == "Cinder shares Empty Cavern with 1 kobold.")
        #expect(state.discoveredPlaces.map(\.id) == ["depths"])
        #expect(world.residents.map(\.id) == ["kobold"])
        #expect(world.facts.map(\.id) == ["mark"])
        #expect(world.abilities.map(\.id) == ["memory"])
        #expect(world.activeThreads.map(\.id) == ["stalker"])
    }
}
