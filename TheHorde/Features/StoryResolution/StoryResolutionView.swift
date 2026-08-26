import SwiftUI

struct StoryResolutionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let event: PendingStorySummary
    @State private var phase: Phase = .idle
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    enum Phase { case idle, generating, committed(ChronicleSummary), failed(String) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let world = app.world { DungeonSceneView(world: world, cue: committed?.cue ?? (event.valence == .positive ? .celebrate : .concern)) }
                    switch phase {
                    case .idle: Color.clear.frame(height: 1)
                    case .generating: generating
                    case .committed(let result): committedView(result)
                    case .failed(let code): failureView(code)
                    }
                }.padding(DesignTokens.margin)
            }
            .navigationTitle("Dungeon Consequence")
            .hordeInlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .interactiveDismissDisabled(false)
        .task { if event.status == .failedRetryable { phase = .failed(event.failureCode ?? "modelFailure") } else { await resolve() } }
    }

    private var generating: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView().controlSize(.large)
            Text(event.valence == .positive ? "Interpreting your completion…" : "Interpreting the missed deadline…").font(.title2.bold())
            Text("“\(event.sourceTitle)” is already saved. You can close this sheet; no dungeon change appears unless the complete result commits.")
        }.accessibilityElement(children: .combine).accessibilityLabel("Generating one local dungeon consequence. The goal event is already saved.")
    }

    private func committedView(_ result: ChronicleSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(result.valence == .positive ? "Completion" : "Recoverable setback", systemImage: result.valence == .positive ? "checkmark.circle.fill" : "clock.badge.exclamationmark").foregroundStyle(result.valence == .positive ? DesignTokens.positive : DesignTokens.negative)
            Text(result.title).font(.largeTitle.bold())
            Text(result.narration).textSelection(.enabled)
            VStack(alignment: .leading, spacing: 8) { Text("What changed").font(.headline); ForEach(result.deltas) { Label($0.description, systemImage: "arrow.right.circle") } }.hordeCard()
            Button("Continue") { dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func failureView(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("No dungeon change was applied", systemImage: "arrow.counterclockwise.circle").font(.title2.bold())
            Text(failureMessage(code))
            Text("Your goal completion or expiration is saved. The world is unchanged, and this story remains available to retry.")
            Button("Retry") { Task { await resolve() } }.buttonStyle(.borderedProminent).controlSize(.large).frame(minHeight: 44)
            Button("Return to Today") { dismiss() }.frame(minHeight: 44)
        }
    }

    private var committed: ChronicleSummary? { if case .committed(let result) = phase { result } else { nil } }

    private func resolve() async {
        phase = .generating
        switch await app.resolve(eventID: event.id) {
        case .committed(let result):
            phase = .committed(result)
            if hapticsEnabled { PlatformSupport.resolutionFeedback(positive: result.valence == .positive) }
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
