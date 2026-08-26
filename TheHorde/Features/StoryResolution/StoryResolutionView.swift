import SwiftUI

enum StoryResolutionPhase: Equatable {
    case loading
    case suggestion(String)
    case accepting(String)
    case customActionEntry(String)
    case accepted(String)
    case committed(ChronicleSummary)
    case failed(String)

    static func opening(_ event: PendingStorySummary) -> Self {
        guard let state = event.resolutionState else {
            return event.status == .failedRetryable ? .failed(event.failureCode ?? "modelFailure") : .loading
        }
        if state.stage == .actionAccepted {
            guard state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
                  let suggestion = state.suggestedAction,
                  let action = try? ActionSuggestionModelContract.validatedAction(suggestion),
                  state.acceptedAction == action else { return .failed("persistenceFailure") }
            return .accepted(action)
        }
        if state.stage == .customActionEntry,
           state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
           let suggestion = state.suggestedAction,
           let action = try? ActionSuggestionModelContract.validatedAction(suggestion) {
            return .customActionEntry(action)
        }
        if state.stage == .actionSuggestion,
           state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
           let suggestion = state.suggestedAction,
           let action = try? ActionSuggestionModelContract.validatedAction(suggestion) {
            return .suggestion(action)
        }
        return event.status == .failedRetryable ? .failed(event.failureCode ?? "modelFailure") : .loading
    }

    mutating func openCustomActionEntry() {
        guard case .suggestion(let action) = self else { return }
        self = .customActionEntry(action)
    }
}

enum StoryResolutionAccessibility {
    static let suggestion = "StoryResolution.Suggestion"
    static let acceptSuggestion = "StoryResolution.AcceptSuggestion"
    static let customAction = "StoryResolution.CustomAction"
    static let customActionEntry = "StoryResolution.CustomActionEntry"
    static let backToSuggestion = "StoryResolution.BackToSuggestion"
    static let retrySuggestion = "StoryResolution.RetrySuggestion"
    static let close = "StoryResolution.Close"
}

struct StoryResolutionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let event: PendingStorySummary
    @State private var phase: StoryResolutionPhase

    init(event: PendingStorySummary) {
        self.event = event
        _phase = State(initialValue: .opening(event))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let world = app.world { DungeonSceneView(world: world, cue: .idle) }
                    switch phase {
                    case .loading: loading
                    case .suggestion(let action): suggestionView(action)
                    case .accepting(let action): acceptingView(action)
                    case .customActionEntry(let action): customActionEntry(action)
                    case .accepted(let action): acceptedView(action)
                    case .committed(let result): committedView(result)
                    case .failed(let code): failureView(code)
                    }
                }.padding(DesignTokens.margin)
            }
            .navigationTitle("Choose an Action")
            .hordeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier(StoryResolutionAccessibility.close)
                }
            }
        }
        .interactiveDismissDisabled(false)
        .task { if phase == .loading { await loadSuggestion() } }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Preparing an action…").font(.title2.bold())
            Text("“\(event.sourceTitle)” is saved. No story or dungeon change is applied while you choose.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing a suggested action. No dungeon change has been applied.")
    }

    private func suggestionView(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggested action").font(.headline).foregroundStyle(.secondary)
            Text(action).font(.largeTitle.bold()).textSelection(.enabled)
                .accessibilityIdentifier(StoryResolutionAccessibility.suggestion)
                .accessibilityLabel("Suggested action: \(action)")
            Text("Choose this action or write your own. Nothing changes in the dungeon until a later final result is committed.")
            Button("Accept & Continue") { Task { await acceptSuggestion(action) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 240)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(StoryResolutionAccessibility.acceptSuggestion)
                .accessibilityHint("Accepts this exact suggestion without generating the final story yet.")
            Button("Write My Own Action") { phase.openCustomActionEntry() }
                .controlSize(.large)
                .keyboardShortcut("e", modifiers: .command)
                .accessibilityIdentifier(StoryResolutionAccessibility.customAction)
                .accessibilityHint("Opens the separate custom action path without accepting the suggestion.")
        }
    }

    private func acceptingView(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Accepting “\(action)”…").font(.title2.bold())
            Text("No story or dungeon change is being generated yet.")
        }
    }

    private func customActionEntry(_ suggestion: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Write your own action", systemImage: "square.and.pencil").font(.largeTitle.bold())
            Text("Custom action entry is the next step. The suggestion has not been accepted, and the dungeon is unchanged.")
            Button("Back to Suggestion") { phase = .suggestion(suggestion) }
                .keyboardShortcut("[", modifiers: .command)
                .accessibilityIdentifier(StoryResolutionAccessibility.backToSuggestion)
                .accessibilityHint("Returns without accepting or submitting an action.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(StoryResolutionAccessibility.customActionEntry)
    }

    private func acceptedView(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Action accepted", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(DesignTokens.positive)
            Text(action).font(.largeTitle.bold()).textSelection(.enabled)
            Text("The action is saved. No final story or dungeon change has been generated yet.")
            Button("Close") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private func committedView(_ result: ChronicleSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(result.valence == .positive ? "Completion" : "Recoverable setback", systemImage: result.valence == .positive ? "checkmark.circle.fill" : "clock.badge.exclamationmark").foregroundStyle(result.valence == .positive ? DesignTokens.positive : DesignTokens.negative)
            Text(result.title).font(.largeTitle.bold())
            Text(result.finalProse).textSelection(.enabled)
            VStack(alignment: .leading, spacing: 8) { Text("What changed").font(.headline); ForEach(result.deltas) { Label($0.description, systemImage: "arrow.right.circle") } }.hordeCard()
            Button("Continue") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func failureView(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("No dungeon change was applied", systemImage: "arrow.counterclockwise.circle").font(.title2.bold())
            Text(failureMessage(code))
            Text("Your goal completion or expiration is saved. The world is unchanged, and this suggestion remains available to retry.")
            Button("Retry") { Task { await loadSuggestion() } }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(StoryResolutionAccessibility.retrySuggestion)
                .frame(minHeight: 44)
            Button("Return to Today") { dismiss() }.frame(minHeight: 44)
        }
    }

    private func loadSuggestion() async {
        phase = .loading
        switch await app.suggestAction(eventID: event.id) {
        case .suggested(let action): phase = .suggestion(action)
        case .failed(let code): phase = .failed(code)
        }
    }

    private func acceptSuggestion(_ action: String) async {
        phase = .accepting(action)
        switch await app.acceptSuggestedAction(eventID: event.id) {
        case .accepted(let accepted): phase = .accepted(accepted)
        case .failed(let code): phase = .failed(code)
        }
    }

    private func failureMessage(_ code: String) -> String {
        switch code {
        case "modelNotReady": "The system’s on-device model is not ready yet. Check again after the system finishes preparing it."
        case "intelligenceDisabled": "Apple Intelligence is turned off. Enable it in Settings before retrying."
        case "unsupportedLocale": "The current app language is not supported by the on-device model."
        case "guardrail": "The on-device model could not safely create this story. No raw response was retained."
        case "contextOverflow": "The local story context did not fit. The event remains safe to retry after compaction."
        case "invalidOutput": "The proposed change did not pass the app’s independent safety and schema checks."
        case "revisionConflict": "The dungeon changed during generation. Retry to rebuild against its latest state."
        case "interrupted": "Generation was interrupted."
        case "persistenceFailure": "The complete result could not be stored atomically."
        default: "The on-device model could not finish this consequence."
        }
    }
}
