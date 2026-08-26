import Foundation
import FoundationModels
import Testing
@testable import TheHorde

@Suite("Model developer log")
struct ModelDevLogTests {
    @Test func preservesExactStringsAndFullRequestMaterialAcrossReload() async throws {
        let fixture = try LogFixture()
        defer { fixture.remove() }
        let instructions = "INSTRUCTIONS\nKeep \u{0000} and 🐉 exactly."
        let prompt = "PROMPT\r\nDo not normalize café."
        let request = try #require(FoundationModelClient.fullRequestText(
            instructions: instructions,
            tool: StageMutationTool(stager: PatchStager()),
            prompt: prompt,
            schema: LegacyModelSchemas.story(for: .positive),
            options: ModelSampling.greedy.generationOptions
        ))
        let response = "{\"title\":\"Café 🐉\",\"line\":\"one\\ntwo\"}"
        let material = "{\"toolCalls\":[{\"arguments\":\"exact\"}]}"
        let entry = makeEntry(
            instructions: instructions,
            prompt: prompt,
            request: request,
            response: response,
            material: material
        )

        await ModelDevLogStore(fileURL: fixture.url, isEnabled: { true }).record(entry)
        let saved = try #require(await ModelDevLogStore(fileURL: fixture.url, isEnabled: { true }).entries().only)

        #expect(Data(saved.instructionsText.utf8) == Data(instructions.utf8))
        #expect(Data(saved.promptText.utf8) == Data(prompt.utf8))
        #expect(Data(try #require(saved.requestText).utf8) == Data(request.utf8))
        #expect(Data(try #require(saved.responseText).utf8) == Data(response.utf8))
        #expect(saved.responseMaterial == material)

        let decoded = try JSONDecoder().decode(Transcript.self, from: Data(try #require(saved.requestText).utf8))
        #expect(decoded.contains { entry in
            guard case .instructions(let value) = entry else { return false }
            return value.toolDefinitions.first?.name == ModelPromptRegistry.text(.legacyToolName)
                && value.toolDefinitions.first?.description == ModelPromptRegistry.text(.legacyToolDescription)
                && value.segments.contains { segment in
                    guard case .text(let text) = segment else { return false }
                    return text.content == instructions
                }
        })
        #expect(decoded.contains { entry in
            guard case .prompt(let value) = entry else { return false }
            return value.responseFormat != nil && value.segments.contains { segment in
                guard case .text(let text) = segment else { return false }
                return text.content == prompt
            }
        })
        #expect(request.contains(ModelPromptRegistry.text(.legacyToolFieldIDGuide)))
        #expect(request.contains(ModelPromptRegistry.text(.legacyPositiveNarrationGuide)))
    }

    @Test func retainsNewestTenInNewestFirstOrder() async throws {
        let fixture = try LogFixture()
        defer { fixture.remove() }
        let store = ModelDevLogStore(fileURL: fixture.url, isEnabled: { true })

        for attempt in 1...11 {
            await store.record(makeEntry(id: "entry-\(attempt)", attempt: attempt))
        }

        #expect(await store.entries().map(\.id) == (2...11).reversed().map { "entry-\($0)" })
    }

    @Test func developerModeOffNeitherPersistsNorExposesEntries() async throws {
        let fixture = try LogFixture()
        defer { fixture.remove() }
        let enabledStore = ModelDevLogStore(fileURL: fixture.url, isEnabled: { true })
        await enabledStore.record(makeEntry(id: "existing"))

        let disabledStore = ModelDevLogStore(fileURL: fixture.url, isEnabled: { false })
        await disabledStore.record(makeEntry(id: "blocked"))
        #expect(await disabledStore.entries().isEmpty)
        #expect(await enabledStore.entries().map(\.id) == ["existing"])
    }

    @Test func anExistingReaderSeesWritesFromAnotherStoreInstance() async throws {
        let fixture = try LogFixture()
        defer { fixture.remove() }
        let reader = ModelDevLogStore(fileURL: fixture.url, isEnabled: { true })
        #expect(await reader.entries().isEmpty)

        await ModelDevLogStore(fileURL: fixture.url, isEnabled: { true }).record(makeEntry(id: "new"))

        #expect(await reader.entries().map(\.id) == ["new"])
    }

    @Test func retriesAreSeparateAndFailuresRetainAvailableMaterial() async throws {
        let fixture = try LogFixture()
        defer { fixture.remove() }
        let store = ModelDevLogStore(fileURL: fixture.url, isEnabled: { true })
        await store.record(makeEntry(
            id: "first",
            attempt: 1,
            outcome: .failed,
            response: "{\"partial\":true}",
            material: "tool-call-material",
            error: "receipt mismatch"
        ))
        await store.record(makeEntry(id: "second", attempt: 2, outcome: .succeeded))

        let entries = await store.entries()
        #expect(entries.map(\.id) == ["second", "first"])
        #expect(entries.map(\.attempt) == [2, 1])
        #expect(entries.last?.outcome == .failed)
        #expect(entries.last?.responseText == "{\"partial\":true}")
        #expect(entries.last?.responseMaterial == "tool-call-material")
        #expect(entries.last?.errorText == "receipt mismatch")
    }

    @Test func browserSearchLocatesEveryStageAndRetryForOneResolution() {
        let resolutionEntries = [
            makeEntry(id: "effort", eventID: "resolution-A", goalTitle: "Defeat the dragon", stage: .effortEvaluation),
            makeEntry(id: "suggestion", eventID: "resolution-A", goalTitle: "Defeat the dragon", stage: .actionSuggestion),
            makeEntry(id: "custom", eventID: "resolution-A", goalTitle: "Defeat the dragon", stage: .customActionInterpretation),
            makeEntry(id: "prose-1", eventID: "resolution-A", goalTitle: "Defeat the dragon", stage: .finalProse, attempt: 1, outcome: .failed),
            makeEntry(id: "prose-2", eventID: "resolution-A", goalTitle: "Defeat the dragon", stage: .finalProse, attempt: 2)
        ]
        let entries = resolutionEntries + [makeEntry(id: "other", eventID: "resolution-B", goalTitle: "Other goal")]

        let matches = ModelDevLogBrowserContent.filtered(entries, query: "resolution-a")

        #expect(matches.map(\.id) == resolutionEntries.map(\.id))
        #expect(Set(matches.map(\.stage)) == Set([
            .effortEvaluation,
            .actionSuggestion,
            .customActionInterpretation,
            .finalProse
        ]))
        #expect(ModelDevLogBrowserContent.filtered(entries, query: "Attempt 2").map(\.id) == ["prose-2"])
        #expect(ModelDevLogBrowserContent.filtered(entries, query: "Final Prose").map(\.id) == ["prose-1", "prose-2"])
        #expect(ModelDevLogBrowserContent.filtered(entries, query: "failed").map(\.id) == ["prose-1"])
    }

    @Test func detailCompositionPreservesEveryStoredTextExactly() throws {
        let entry = makeEntry(
            instructions: "  instructions\n🐉\u{0000}",
            prompt: "prompt\r\nwith trailing space ",
            request: "{\"request\":\"exact\\ntext\"}",
            response: "{\"response\":\"café\"}",
            material: "{\"toolCall\":true}",
            transcript: "[\"exact transcript\"]",
            error: "failure details"
        )

        let sections = Dictionary(uniqueKeysWithValues: ModelDevLogBrowserContent.textSections(for: entry).map { ($0.title, $0.text) })

        #expect(try #require(sections["Full Request"]) == entry.requestText)
        #expect(try #require(sections["Raw Response"]) == entry.responseText)
        #expect(try #require(sections["Response Material"]) == entry.responseMaterial)
        #expect(try #require(sections["Instructions"]) == entry.instructionsText)
        #expect(try #require(sections["Prompt"]) == entry.promptText)
        #expect(try #require(sections["Attempt Transcript"]) == entry.attemptTranscript)
        #expect(try #require(sections["Error"]) == entry.errorText)
    }

    @Test func inspectorUsesExactCapturedTextAndDeterministicFallbacks() {
        let exact = makeEntry(
            instructions: "stored instructions",
            prompt: "stored prompt",
            request: "exact request\n",
            response: "exact response\r\n",
            material: "structured material",
            transcript: "transcript",
            error: "error"
        )
        #expect(ModelDevLogBrowserContent.requestText(for: exact) == "exact request\n")
        let exactResponse = "Raw Response\nexact response\r\n\n\n---\n\nResponse Material\nstructured material\n\n---\n\nError\nerror"
        #expect(ModelDevLogBrowserContent.responseText(for: exact) == exactResponse)
        #expect(ModelDevLogBrowserContent.bothText(for: exact) == "REQUEST\nexact request\n\n\nRESPONSE\n\(exactResponse)")

        let missingEnvelope = makeEntry(
            instructions: "stored instructions",
            prompt: "stored prompt",
            request: nil,
            response: nil,
            material: "structured material",
            transcript: "transcript",
            error: "error"
        )
        #expect(ModelDevLogBrowserContent.requestText(for: missingEnvelope) == "Instructions:\nstored instructions\n\nPrompt:\nstored prompt")
        #expect(ModelDevLogBrowserContent.responseText(for: missingEnvelope) == "Response Material\nstructured material\n\n---\n\nError\nerror")

        let transcriptOnly = makeEntry(request: nil, response: nil, material: nil, transcript: "transcript", error: "error")
        #expect(ModelDevLogBrowserContent.responseText(for: transcriptOnly) == "Attempt Transcript\ntranscript\n\n---\n\nError\nerror")

        let errorOnly = makeEntry(request: nil, response: nil, material: nil, transcript: nil, error: "error")
        #expect(ModelDevLogBrowserContent.responseText(for: errorOnly) == "Error\nerror")

        let unavailable = makeEntry(request: nil, response: nil, material: nil, transcript: nil, error: nil)
        #expect(ModelDevLogBrowserContent.responseText(for: unavailable) == "No response was captured.")
    }

    private func makeEntry(
        id: String = "entry",
        eventID: String = "event",
        goalTitle: String = "Goal",
        stage: ModelRequestStageID = .legacyConsequence,
        attempt: Int = 1,
        outcome: ModelAttemptOutcome = .succeeded,
        instructions: String = "instructions",
        prompt: String = "prompt",
        request: String? = "request material",
        response: String? = "response",
        material: String? = "response material",
        transcript: String? = "attempt transcript",
        error: String? = nil
    ) -> ModelDevLogEntry {
        ModelDevLogEntry(
            id: id,
            timestamp: Date(timeIntervalSince1970: Double(attempt)),
            eventID: eventID,
            goalTitle: goalTitle,
            stage: stage,
            attempt: attempt,
            outcome: outcome,
            instructionsText: instructions,
            promptText: prompt,
            requestText: request,
            responseText: response,
            responseMaterial: material,
            attemptTranscript: transcript,
            errorText: error
        )
    }
}

private struct LogFixture {
    let directory: URL
    var url: URL { directory.appending(path: "ModelDevLogs.json") }

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private extension Collection {
    var only: Element? { count == 1 ? first : nil }
}
