#if DEBUG
import Foundation

struct ProductVerificationFixture {
    let world: WorldReadModel
    let occurrences: [GoalOccurrenceSummary]
    let pendingStories: [PendingStorySummary]
    let chronicle: [ChronicleSummary]

    var definitions: [GoalDefinitionSummary] {
        Dictionary(grouping: occurrences, by: \.definitionID).map { id, history in
            let source = history[0].snapshot
            return GoalDefinitionSummary(
                id: id,
                draft: GoalDraft(
                    title: source.title,
                    notes: source.notes,
                    dueDate: history.first(where: { $0.state == .pending })?.dueDate,
                    includesTime: history.first(where: { $0.state == .pending })?.includesTime ?? false,
                    recurrence: source.recurrence,
                    category: source.category,
                    effort: source.effort
                ),
                version: source.definitionVersion,
                archived: false,
                history: history
            )
        }
    }

    static func named(_ name: String) -> Self? {
        switch name {
        case "normal": scene(.normal)
        case "hazard": scene(.hazard)
        case "recovery": scene(.recovery)
        case "populated": populated
        case "showcase": showcase
        default: nil
        }
    }

    private enum Scene { case normal, hazard, recovery }

    private static func scene(_ scene: Scene) -> Self {
        var world = WorldSnapshot.initial()
        switch scene {
        case .normal:
            break
        case .hazard:
            world.morale = 38
            world.integrity = 42
            world.activeThreads = [ActiveThreadState(id: "rain-leak", title: "Rain Through the Ceiling", severity: 3, state: "active", involvedEntityIDs: ["dragon", "empty-cavern"], summary: "Ember braces the cracked cavern ceiling before floodwater scours the bare floor.")]
            world.rollingSummary = "Rainwater cuts through the cracked cavern ceiling as Ember races alone to shore the breach."
        case .recovery:
            world.morale = 63
            world.integrity = 57
            world.food = 61
            world.activeThreads = []
            world.abilities = [AbilityState(id: "ember-memory", name: "Ember Memory", summary: "Hard-won repairs teach Ember how to reinforce the cavern.", rank: 2)]
            world.rollingSummary = "Ember seals the breach and steadies the cavern after a hard-won restoration."
        }
        return Self(world: WorldReadModel(dungeonName: "The Cinder Vault", revision: 8, snapshot: world), occurrences: [], pendingStories: [], chronicle: [])
    }

    private static var showcase: Self {
        let now = Date.now
        var fixture = scene(.recovery)
        let today = occurrence("today", "Review the project plan", due: now.addingTimeInterval(3_600), category: .work, effort: .medium, recurrence: .daily)
        let overdue = occurrence("overdue", "Water the basil seedlings", due: now.addingTimeInterval(-3_600), category: .home, effort: .small)
        let upcoming = occurrence("upcoming", "Practice the guitar bridge", due: now.addingTimeInterval(86_400), category: .personal, effort: .medium, recurrence: .weekdays([2, 4, 6]))
        let pending = PendingStorySummary(id: "pending-story", sourceTitle: "File the workshop notes", sourceCategory: .work, sourceEffort: .large, valence: .positive, status: .pending, failureCode: nil, createdAt: now.addingTimeInterval(-600))
        fixture = Self(
            world: fixture.world,
            occurrences: [overdue, today, upcoming],
            pendingStories: [pending],
            chronicle: [
                story(0, "The Lantern Ledger", "File the workshop notes", "Bind the workshop ledger", .positive, .celebrate, "Ember seals the sorted notes in an ironbound ledger and claims their hard-earned knowledge.", "The finished ledger strengthens Ember’s command.", "Morale: 59 → 63", fixture.world),
                story(1, "The West Passage Brace", "Repair the loose shelf", "Fortify the west passage", .positive, .recover, "Ember reforges the broken shelf braces, then armors the west passage with the salvaged timber.", "The vault’s defenses hold stronger.", "Integrity: 53 → 57", fixture.world),
                story(2, "The Harvest Muster", "Plan tomorrow’s meals", "Command the deep harvest", .positive, .resourceChanges, "Ember turns the finished meal plan into an exacting harvest command for the deep galleries.", "The pantry holds provisions for the trials ahead.", "Food: 57 → 61", fixture.world),
                story(3, "Rain at the Door", "Bring in the garden tools", "Abandon tools to storm", .negative, .hazardAppears, "The missed deadline leaves iron tools exposed to a driving storm; rust claims their edges as floodwater breaches the threshold.", "The breach ruins supplies and opens a new threat.", "New thread: Flooded Threshold", fixture.world),
                story(4, "The Lightless Passage", "Replace the hallway bulb", "Enter the lightless passage", .negative, .concern, "Ember enters the unlit passage, but a stalking cave beast drives the young dragon back into the cavern.", "Darkness cedes the passage to a lurking threat.", "Morale: 61 → 59", fixture.world),
                story(5, "The Wyrm-Lore Codex", "Read before bed", "Study the wyrm-lore codex", .positive, .idle, "Ember studies the final chapter and uncovers the ward-sign that seals the lower vault.", "Ancient ward-lore enters the Chronicle.", "New fact: The Lower Vault Ward", fixture.world)
            ]
        )
        return fixture
    }

    private static var populated: Self {
        var world = WorldSnapshot.initial()
        world.dragonVisual = DragonVisualState(stage: .adult, color: CuratedDragonColor.ruby.color)
        world.hoard = 60
        world.morale = 58
        world.integrity = 46
        world.food = 32
        world.residents = [CharacterState(
            id: "kobold-rill", name: "Rill", role: "Young scout", identity: "A watchful cavern scout.", vitality: 50, bond: 50, conditions: [],
            koboldVisual: KoboldVisualState(
                age: .kid,
                colors: CharacterPalette(
                    primary: RGBColor(red: 58, green: 107, blue: 190),
                    secondary: RGBColor(red: 145, green: 69, blue: 160)
                )
            )
        )]
        world.locations.append(LocationState(id: "echoing-depths", name: "Echoing Depths", status: "Discovered", summary: "A newly mapped passage."))
        world.facts = [WorldFact(id: "wyrm-mark", title: "The Wyrm Mark", summary: "A carved sign points deeper underground.")]
        world.abilities = [AbilityState(id: "ember-memory", name: "Ember Memory", summary: "The dragon remembers completed work.", rank: 1)]
        world.activeThreads = [ActiveThreadState(id: "stone-stalker", title: "Stone Stalker", severity: 2, state: "active", involvedEntityIDs: ["dragon", "kobold-rill"], summary: "Something dangerous moves beyond the mapped passage.")]
        return Self(world: WorldReadModel(dungeonName: "The Cinder Vault", revision: 8, snapshot: world), occurrences: [], pendingStories: [], chronicle: [])
    }

    private static func occurrence(_ id: String, _ title: String, due: Date, category: GoalCategory, effort: GoalEffort, recurrence: RecurrenceRule = .never) -> GoalOccurrenceSummary {
        GoalOccurrenceSummary(id: id, definitionID: "definition-\(id)", snapshot: GoalSnapshot(title: title, notes: "A deterministic product-verification example.", category: category, effort: effort, recurrence: recurrence, definitionVersion: 1), dueDate: due, includesTime: true, state: .pending, resolvedAt: nil, hasPendingStory: false)
    }

    private static func story(_ index: Int, _ title: String, _ source: String, _ acceptedAction: String, _ valence: EventValence, _ cue: AnimationCue, _ finalProse: String, _ summary: String, _ delta: String, _ recordedWorld: WorldReadModel) -> ChronicleSummary {
        ChronicleSummary(id: "story-\(index)", eventID: "fixture-event-\(index)", sourceTitle: source, valence: valence, title: title, finalProse: finalProse, summary: summary, deltas: [WorldDelta(fieldID: "fixture", description: delta)], cue: cue, priorRevision: index, committedRevision: index + 1, committedAt: Date.now.addingTimeInterval(Double(-index * 3_600)), effort: ResolutionEffort(rating: .two, source: .userSelected), comparisonHistoryIDs: [], acceptedAction: acceptedAction, recordedWorld: recordedWorld)
    }
}
#endif
