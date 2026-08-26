import SwiftUI

enum StoryResolutionPhase: Equatable {
    case loading
    case suggestion(String)
    case accepting(String)
    case customActionEntry(String)
    case interpretingCustomAction(String)
    case interpretedActionReady(String)
    case accepted(String)
    case finalProse(action: String, prose: String)
    case committing(String)
    case committed(ChronicleSummary)
    case failed(String)

    static func opening(_ event: PendingStorySummary) -> Self {
        guard let state = event.resolutionState else {
            return event.status == .failedRetryable ? .failed(event.failureCode ?? "modelFailure") : .loading
        }
        if state.stage == .finalProse {
            guard let action = authoritativeAcceptedAction(in: state),
                  state.promptVersions.finalProse == FinalProseModelContract.promptVersion,
                  let prose = state.finalProse,
                  (try? FinalProseModelContract.validatedProse(prose)) == prose,
                  state.finalResult == nil else { return .failed("persistenceFailure") }
            return .finalProse(action: action, prose: prose)
        }
        if state.stage == .actionAccepted {
            guard let action = authoritativeAcceptedAction(in: state),
                  state.promptVersions.finalProse == nil,
                  state.finalProse == nil,
                  state.finalResult == nil else { return .failed("persistenceFailure") }
            return .accepted(action)
        }
        if state.stage == .interpretedActionReview,
           hasCurrentEffort(state),
           state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
           state.promptVersions.interpretation == CustomActionModelContract.promptVersion,
           let suggestion = state.suggestedAction,
           (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
           let customAction = state.customAction,
           !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let interpretation = state.interpretedAction,
           (try? CustomActionModelContract.validatedAction(interpretation)) == interpretation,
           state.acceptedAction == nil,
           state.promptVersions.finalProse == nil,
           state.finalProse == nil,
           state.finalResult == nil {
            return .interpretedActionReady(interpretation)
        }
        if state.stage == .customActionEntry,
           hasCurrentEffort(state),
           state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
           let suggestion = state.suggestedAction,
           (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
           let customAction = state.customAction,
           !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           state.interpretedAction == nil,
           state.acceptedAction == nil,
           state.promptVersions.interpretation == nil,
           state.promptVersions.finalProse == nil,
           state.finalProse == nil,
           state.finalResult == nil {
            return .customActionEntry(suggestion)
        }
        if state.stage == .actionSuggestion,
           hasCurrentEffort(state),
           state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
           let suggestion = state.suggestedAction,
           (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
           state.customAction == nil,
           state.interpretedAction == nil,
           state.acceptedAction == nil,
           state.promptVersions.interpretation == nil,
           state.promptVersions.finalProse == nil,
           state.finalProse == nil,
           state.finalResult == nil {
            return .suggestion(suggestion)
        }
        if state.stage == .effortSelection,
           state.suggestedAction == nil,
           state.customAction == nil,
           state.interpretedAction == nil,
           state.acceptedAction == nil,
           state.promptVersions.suggestion == nil,
           state.promptVersions.interpretation == nil,
           state.promptVersions.finalProse == nil,
           state.finalProse == nil,
           state.finalResult == nil,
           hasCurrentOrPendingEffort(state) {
            return event.status == .failedRetryable ? .failed(event.failureCode ?? "modelFailure") : .loading
        }
        return .failed("persistenceFailure")
    }

    static func customActionDraft(opening event: PendingStorySummary) -> String {
        event.resolutionState?.customAction ?? ""
    }

    private static func hasCurrentEffort(_ state: StagedResolutionState) -> Bool {
        guard let effort = state.effort,
              Set(state.comparisonHistoryIDs).count == state.comparisonHistoryIDs.count,
              state.comparisonHistoryIDs.count <= AttemptedGoalHistory.maximumCount else { return false }
        return effort.source == .userSelected
            ? state.promptVersions.effort == nil && state.comparisonHistoryIDs.isEmpty
            : state.promptVersions.effort == EffortModelContract.promptVersion
    }

    private static func authoritativeAcceptedAction(in state: StagedResolutionState) -> String? {
        guard hasCurrentEffort(state),
              state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
              let suggestion = state.suggestedAction,
              (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
              let acceptedAction = state.acceptedAction else { return nil }
        if let customAction = state.customAction {
            guard !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  state.promptVersions.interpretation == CustomActionModelContract.promptVersion,
                  let interpretation = state.interpretedAction,
                  (try? CustomActionModelContract.validatedAction(interpretation)) == interpretation,
                  acceptedAction == interpretation else { return nil }
            return acceptedAction
        }
        guard state.interpretedAction == nil,
              state.promptVersions.interpretation == nil,
              acceptedAction == suggestion else { return nil }
        return acceptedAction
    }

    private static func hasCurrentOrPendingEffort(_ state: StagedResolutionState) -> Bool {
        state.effort == nil
            ? state.promptVersions.effort == nil && state.comparisonHistoryIDs.isEmpty
            : hasCurrentEffort(state)
    }

    mutating func openCustomActionEntry() {
        guard case .suggestion(let action) = self else { return }
        self = .customActionEntry(action)
    }

    mutating func beginInterpreting(customAction: String) -> String? {
        guard case .customActionEntry(let suggestion) = self,
              !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self = .interpretingCustomAction(suggestion)
        return customAction
    }

    mutating func returnToSuggestion() {
        guard case .customActionEntry(let suggestion) = self else { return }
        self = .suggestion(suggestion)
    }
}

enum StoryResolutionAccessibility {
    static let suggestion = "StoryResolution.Suggestion"
    static let acceptSuggestion = "StoryResolution.AcceptSuggestion"
    static let customAction = "StoryResolution.CustomAction"
    static let customActionEntry = "StoryResolution.CustomActionEntry"
    static let interpretCustomAction = "StoryResolution.InterpretCustomAction"
    static let interpretingCustomAction = "StoryResolution.InterpretingCustomAction"
    static let interpretedActionReady = "StoryResolution.InterpretedActionReady"
    static let acceptInterpretedAction = "StoryResolution.AcceptInterpretedAction"
    static let reviseAction = "StoryResolution.ReviseAction"
    static let backToSuggestion = "StoryResolution.BackToSuggestion"
    static let retrySuggestion = "StoryResolution.RetrySuggestion"
    static let close = "StoryResolution.Close"
    static let commitFinalResolution = "StoryResolution.CommitFinalResolution"
    static let state = "StoryResolution.State"
}

struct StoryResolutionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let event: PendingStorySummary
    @State private var phase: StoryResolutionPhase
    @State private var customAction: String
    @FocusState private var customActionFocused: Bool

    init(event: PendingStorySummary) {
        self.event = event
        _phase = State(initialValue: .opening(event))
        _customAction = State(initialValue: StoryResolutionPhase.customActionDraft(opening: event))
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
                    case .interpretingCustomAction: interpretingCustomActionView
                    case .interpretedActionReady(let action): interpretedActionReadyView(action)
                    case .accepted(let action): acceptedView(action)
                    case .finalProse(let action, let prose): finalProseView(action: action, prose: prose)
                    case .committing(let action): committingView(action)
                    case .committed(let result): committedView(result)
                    case .failed(let code): failureView(code)
                    }
                }
                .padding(DesignTokens.margin)
            }
            .accessibilityIdentifier(StoryResolutionAccessibility.state)
            .accessibilityValue(stateAccessibilityValue)
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
        .task {
            switch phase {
            case .loading: await loadSuggestion()
            case .accepted(let action): await resumeFinalProse(action: action)
            default: break
            }
        }
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

    private var stateAccessibilityValue: String {
        let action: String
        switch phase {
        case .accepted(let value), .finalProse(let value, _), .committing(let value): action = value
        default: action = "none"
        }
        return "Dungeon revision \(app.world?.revision ?? -1); Chronicle entries \(app.chronicle.count); Accepted action \(action)"
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
            Text("Describe what the dragon should do. Your exact text will be interpreted before you review it.")
            TextEditor(text: $customAction)
                .frame(minHeight: 120)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: DesignTokens.radius))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.radius).stroke(.secondary.opacity(0.4)))
                .focused($customActionFocused)
                .accessibilityIdentifier(StoryResolutionAccessibility.customActionEntry)
                .accessibilityLabel("Custom story action")
                .accessibilityHint("Enter the action to interpret. Your text is submitted exactly as written.")
            Button("Interpret Action") { submitCustomAction() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier(StoryResolutionAccessibility.interpretCustomAction)
                .accessibilityHint("Submits this exact text for interpretation without accepting an action or changing the dungeon.")
            Button("Back to Suggestion") { phase.returnToSuggestion() }
                .keyboardShortcut("[", modifiers: .command)
                .accessibilityIdentifier(StoryResolutionAccessibility.backToSuggestion)
                .accessibilityHint("Returns without accepting or submitting an action.")
        }
        .accessibilityElement(children: .contain)
        .onAppear { customActionFocused = true }
    }

    private var interpretingCustomActionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Interpreting your action…").font(.title2.bold())
            Text("No story or dungeon change is being generated yet.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StoryResolutionAccessibility.interpretingCustomAction)
    }

    private func interpretedActionReadyView(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(action).font(.largeTitle.bold()).textSelection(.enabled)
                .accessibilityIdentifier(StoryResolutionAccessibility.interpretedActionReady)
                .accessibilityLabel("Interpreted action: \(action)")
            Button("Accept & Continue") { Task { await acceptInterpretedAction(action) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(StoryResolutionAccessibility.acceptInterpretedAction)
                .accessibilityHint("Accepts this exact interpreted action without changing the dungeon.")
            Button("Revise Action") { Task { await reviseCustomAction() } }
                .controlSize(.large)
                .keyboardShortcut("e", modifiers: .command)
                .accessibilityIdentifier(StoryResolutionAccessibility.reviseAction)
                .accessibilityHint("Returns to your exact custom draft without changing the dungeon.")
        }
        .accessibilityElement(children: .contain)
    }

    private func acceptedView(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Action accepted", systemImage: "checkmark.circle.fill").font(.title2.bold()).foregroundStyle(DesignTokens.positive)
            Text(action).font(.largeTitle.bold()).textSelection(.enabled)
            ProgressView().controlSize(.large)
            Text("The saved action is now authoritative. Preparing final narration from this exact action…")
        }
    }

    private func finalProseView(action: String, prose: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accepted action").font(.headline).foregroundStyle(.secondary)
            Text(action).font(.title2.bold()).textSelection(.enabled)
            Text("Final narration").font(.headline).foregroundStyle(.secondary)
            Text(prose).textSelection(.enabled)
            Text("The dungeon and Chronicle remain unchanged until the final result is committed.")
            Button("Continue to Consequence") { Task { await commitFinalResolution(action: action) } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(StoryResolutionAccessibility.commitFinalResolution)
                .accessibilityHint("Generates authorized world effects and atomically commits this exact narration.")
            Button("Close") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private func committingView(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Applying “\(action)”…").font(.title2.bold())
            Text("The accepted action and final narration are fixed while authorized world effects are prepared.")
        }
        .accessibilityElement(children: .combine)
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
            Button("Retry") { Task { await retryCurrentStage() } }
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
        case .generated(let accepted, let prose): phase = .finalProse(action: accepted, prose: prose)
        case .failed(let code): phase = .failed(code)
        }
    }

    private func submitCustomAction() {
        guard let exactAction = phase.beginInterpreting(customAction: customAction),
              case .interpretingCustomAction(let suggestion) = phase else { return }
        Task {
            switch await app.interpretCustomAction(eventID: event.id, customAction: exactAction) {
            case .interpreted(let action): phase = .interpretedActionReady(action)
            case .failed: phase = .customActionEntry(suggestion)
            }
        }
    }

    private func acceptInterpretedAction(_ action: String) async {
        phase = .accepting(action)
        switch await app.acceptInterpretedAction(eventID: event.id) {
        case .generated(let accepted, let prose): phase = .finalProse(action: accepted, prose: prose)
        case .failed(let code): phase = .failed(code)
        }
    }

    private func resumeFinalProse(action: String) async {
        switch await app.generateFinalProse(eventID: event.id) {
        case .generated(let prose): phase = .finalProse(action: action, prose: prose)
        case .failed(let code): phase = .failed(code)
        }
    }

    private func commitFinalResolution(action: String) async {
        phase = .committing(action)
        switch await app.resolve(eventID: event.id) {
        case .committed(let result): phase = .committed(result)
        case .failed(let code): phase = .failed(code)
        }
    }

    private func retryCurrentStage() async {
        guard let latest = app.pendingStories.first(where: { $0.id == event.id }) else {
            await loadSuggestion()
            return
        }
        switch StoryResolutionPhase.opening(latest) {
        case .finalProse(let action, _): await commitFinalResolution(action: action)
        case .accepted(let action): await resumeFinalProse(action: action)
        default: await loadSuggestion()
        }
    }

    private func reviseCustomAction() async {
        switch await app.reviseCustomAction(eventID: event.id) {
        case .revised(let draft, let suggestion):
            customAction = draft
            phase = .customActionEntry(suggestion)
        case .failed(let code):
            phase = .failed(code)
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
