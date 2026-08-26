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
            world.activeThreads = [ActiveThreadState(id: "rain-leak", title: "Rain in the North Gallery", severity: 3, state: "active", involvedEntityIDs: ["dragon", "kobold-rill"], summary: "Rill and Ember are containing a small leak before it reaches the lantern stores.")]
            world.rollingSummary = "A leak has made the north gallery tense, but the household has a safe repair plan."
        case .recovery:
            world.morale = 63
            world.integrity = 57
            world.food = 61
            world.activeThreads = []
            world.abilities = [AbilityState(id: "ember-memory", name: "Ember Memory", summary: "Finished work helps Ember keep the vault organized.", rank: 2)]
            world.rollingSummary = "The repaired vault is bright, well supplied, and settling into a hopeful rhythm."
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
                story(0, "The Lantern Ledger", "File the workshop notes", .positive, .celebrate, "Pip binds the sorted notes beside the hearth while Ember lights a fresh reading lamp.", "The finished notes lift the household.", "Morale: 59 → 63"),
                story(1, "A Careful Patch", "Repair the loose shelf", .positive, .recover, "Rill braces the shelf and uses the spare timber to mend the west passage trim.", "The vault grows sturdier.", "Integrity: 53 → 57"),
                story(2, "Mushrooms for Supper", "Plan tomorrow’s meals", .positive, .resourceChanges, "Moss turns the finished meal plan into a tidy harvest list for the gallery.", "The pantry is comfortably stocked.", "Food: 57 → 61"),
                story(3, "Rain at the Door", "Bring in the garden tools", .negative, .hazardAppears, "A missed deadline leaves two tools in the rain, so the kobolds start a calm drying rota.", "A small recoverable hazard appears.", "New thread: Damp Tool Rack"),
                story(4, "A Dimmer Evening", "Replace the hallway bulb", .negative, .concern, "The hallway stays dim for one evening, and Pip marks the safest lantern route.", "The household adapts without alarm.", "Morale: 61 → 59"),
                story(5, "A Quiet Page", "Read before bed", .positive, .idle, "Ember listens while one more chapter settles the room into a peaceful hush.", "A calm fact joins the Chronicle.", "New fact: The Bedtime Chapter")
            ]
        )
        return fixture
    }

    private static func occurrence(_ id: String, _ title: String, due: Date, category: GoalCategory, effort: GoalEffort, recurrence: RecurrenceRule = .never) -> GoalOccurrenceSummary {
        GoalOccurrenceSummary(id: id, definitionID: "definition-\(id)", snapshot: GoalSnapshot(title: title, notes: "A deterministic product-verification example.", category: category, effort: effort, recurrence: recurrence, definitionVersion: 1), dueDate: due, includesTime: true, state: .pending, resolvedAt: nil, hasPendingStory: false)
    }

    private static func story(_ index: Int, _ title: String, _ source: String, _ valence: EventValence, _ cue: AnimationCue, _ narration: String, _ summary: String, _ delta: String) -> ChronicleSummary {
        ChronicleSummary(id: "story-\(index)", eventID: "fixture-event-\(index)", sourceTitle: source, valence: valence, title: title, narration: narration, summary: summary, deltas: [WorldDelta(fieldID: "fixture", description: delta)], cue: cue, priorRevision: index, committedRevision: index + 1, committedAt: Date.now.addingTimeInterval(Double(-index * 3_600)))
    }
}
#endif
