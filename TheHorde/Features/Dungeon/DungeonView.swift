import SwiftUI

struct WorldPresentationState {
    let snapshot: WorldSnapshot

    var lair: LocationState? { snapshot.locations.first { $0.id == "empty-cavern" } ?? snapshot.locations.first }
    var discoveredPlaces: [LocationState] { snapshot.locations.filter { $0.id != lair?.id } }
    var isLoneDragon: Bool { snapshot.residents.isEmpty }
    var populationSummary: String {
        if isLoneDragon { return "\(snapshot.dragon.name) is alone in \(lair?.name ?? "the cavern")." }
        return "\(snapshot.dragon.name) shares \(lair?.name ?? "the cavern") with \(snapshot.residents.count) \(snapshot.residents.count == 1 ? "kobold" : "kobolds")."
    }
}

struct DungeonView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            if let world = app.world {
                let presentation = WorldPresentationState(snapshot: world.snapshot)
                VStack(alignment: .leading, spacing: 18) {
                    DungeonSceneView(world: world, cue: .idle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(world.dungeonName).font(.title.bold())
                        Text(world.snapshot.rollingSummary).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    statGrid(world.snapshot)
                    Text("Dragon").font(.title2.bold())
                    characterCard(world.snapshot.dragon)
                        .accessibilityIdentifier("Dungeon.Dragon")
                    Text("Population").font(.title2.bold())
                    if presentation.isLoneDragon {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("No other residents yet").font(.headline)
                                Text(presentation.populationSummary).font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "person.slash") }
                        .hordeCard()
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("Dungeon.Population.Empty")
                    } else {
                        ForEach(world.snapshot.residents) { characterCard($0) }
                    }
                    if !world.snapshot.abilities.isEmpty {
                        Text("Abilities").font(.title2.bold())
                        ForEach(world.snapshot.abilities) { ability in NavigationLink { WorldEntityDetail(title: ability.name, subtitle: "Ability • Rank \(ability.rank)", body: ability.summary) } label: { Label { VStack(alignment: .leading) { Text(ability.name).font(.headline); Text("Rank \(ability.rank) • \(ability.summary)").font(.subheadline) } } icon: { Image(systemName: "sparkles") }.hordeCard() }.buttonStyle(.plain) }
                    }
                    if let lair = presentation.lair {
                        Text("Lair").font(.title2.bold())
                        locationCard(lair)
                    }
                    if !presentation.discoveredPlaces.isEmpty {
                        Text("Discovered Places").font(.title2.bold())
                        ForEach(presentation.discoveredPlaces) { locationCard($0) }
                    }
                    if !world.snapshot.facts.isEmpty {
                        Text("Facts").font(.title2.bold())
                        ForEach(world.snapshot.facts) { fact in NavigationLink { WorldEntityDetail(title: fact.title, subtitle: "Persistent fact", body: fact.summary) } label: { Label(fact.title, systemImage: "scroll").frame(maxWidth: .infinity, alignment: .leading).hordeCard() }.buttonStyle(.plain) }
                    }
                    if !world.snapshot.activeThreads.isEmpty {
                        Text("Threats").font(.title2.bold())
                        ForEach(world.snapshot.activeThreads) { thread in NavigationLink { WorldEntityDetail(title: thread.title, subtitle: "Threat • Severity \(thread.severity)", body: thread.summary) } label: { VStack(alignment: .leading, spacing: 6) {
                            Label("Threat • Severity \(thread.severity)", systemImage: "exclamationmark.triangle").font(.headline)
                            Text(thread.title).font(.title3.bold()); Text(thread.summary)
                        }.hordeCard() }.buttonStyle(.plain) }
                    }
                }.padding(DesignTokens.margin)
            } else { ProgressView("Loading dungeon").padding() }
        }
        .navigationTitle("Dungeon")
        .task { await app.reload() }
    }

    private func statGrid(_ world: WorldSnapshot) -> some View {
        Grid(horizontalSpacing: 12) { GridRow { stat("Morale", world.morale, "face.smiling"); stat("Integrity", world.integrity, "shield"); stat("Food", world.food, "takeoutbag.and.cup.and.straw") } }
    }

    private func stat(_ name: String, _ value: Int, _ icon: String) -> some View {
        VStack { Image(systemName: icon).font(.title2); Text("\(value)").font(.title3.bold()); Text(name).font(.caption) }.frame(maxWidth: .infinity, minHeight: 88).hordeCard().accessibilityElement(children: .combine).accessibilityLabel("\(name), \(value) out of 100")
    }

    private func characterCard(_ character: CharacterState) -> some View {
        NavigationLink { WorldEntityDetail(title: character.name, subtitle: character.role, body: character.identity + (character.conditions.isEmpty ? "" : "\n\nConditions: " + character.conditions.joined(separator: ", "))) } label: { VStack(alignment: .leading, spacing: 4) { Text(character.name).font(.headline); Text(character.role).font(.subheadline).foregroundStyle(.secondary); Text(character.identity) }.frame(maxWidth: .infinity, alignment: .leading).hordeCard() }.buttonStyle(.plain)
    }

    private func locationCard(_ location: LocationState) -> some View {
        NavigationLink { WorldEntityDetail(title: location.name, subtitle: location.status, body: location.summary) } label: { Label { VStack(alignment: .leading) { Text(location.name); Text(location.status).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "mappin.and.ellipse") }.frame(maxWidth: .infinity, alignment: .leading).hordeCard() }.buttonStyle(.plain)
    }
}

private struct WorldEntityDetail: View {
    let title: String
    let subtitle: String
    let text: String
    init(title: String, subtitle: String, body: String) { self.title = title; self.subtitle = subtitle; self.text = body }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text(subtitle).font(.headline).foregroundStyle(.secondary); Text(text).textSelection(.enabled) }.frame(maxWidth: .infinity, alignment: .leading).padding() }.navigationTitle(title) }
}
