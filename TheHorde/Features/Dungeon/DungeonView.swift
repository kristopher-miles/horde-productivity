import SwiftUI

struct DungeonView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            if let world = app.world {
                VStack(alignment: .leading, spacing: 18) {
                    DungeonSceneView(world: world, cue: .idle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(world.dungeonName).font(.title.bold())
                        Text(world.snapshot.rollingSummary).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    statGrid(world.snapshot)
                    if let thread = world.snapshot.activeThreads.first {
                        NavigationLink { WorldEntityDetail(title: thread.title, subtitle: "Active thread • Severity \(thread.severity)", body: thread.summary) } label: { VStack(alignment: .leading, spacing: 6) {
                            Label("Active thread • Severity \(thread.severity)", systemImage: "exclamationmark.triangle") .font(.headline)
                            Text(thread.title).font(.title3.bold()); Text(thread.summary)
                        }.hordeCard() }.buttonStyle(.plain)
                    }
                    Text("Residents").font(.title2.bold())
                    characterCard(world.snapshot.dragon)
                    ForEach(world.snapshot.residents) { characterCard($0) }
                    if !world.snapshot.abilities.isEmpty {
                        Text("Abilities").font(.title2.bold())
                        ForEach(world.snapshot.abilities) { ability in NavigationLink { WorldEntityDetail(title: ability.name, subtitle: "Ability • Rank \(ability.rank)", body: ability.summary) } label: { Label { VStack(alignment: .leading) { Text(ability.name).font(.headline); Text("Rank \(ability.rank) • \(ability.summary)").font(.subheadline) } } icon: { Image(systemName: "sparkles") }.hordeCard() }.buttonStyle(.plain) }
                    }
                    Text("Places & Facts").font(.title2.bold())
                    ForEach(world.snapshot.locations) { location in NavigationLink { WorldEntityDetail(title: location.name, subtitle: location.status, body: location.summary) } label: { Label(location.name, systemImage: "mappin.and.ellipse").frame(maxWidth: .infinity, alignment: .leading).hordeCard() }.buttonStyle(.plain) }
                    ForEach(world.snapshot.facts.suffix(4)) { fact in NavigationLink { WorldEntityDetail(title: fact.title, subtitle: "Persistent fact", body: fact.summary) } label: { Label(fact.title, systemImage: "scroll").frame(maxWidth: .infinity, alignment: .leading).hordeCard() }.buttonStyle(.plain) }
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
}

private struct WorldEntityDetail: View {
    let title: String
    let subtitle: String
    let text: String
    init(title: String, subtitle: String, body: String) { self.title = title; self.subtitle = subtitle; self.text = body }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) { Text(subtitle).font(.headline).foregroundStyle(.secondary); Text(text).textSelection(.enabled) }.frame(maxWidth: .infinity, alignment: .leading).padding() }.navigationTitle(title) }
}
