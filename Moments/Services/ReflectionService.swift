import Foundation

final class ReflectionService {
    static let shared = ReflectionService()

    private init() {}

    func generateReflection(for countdown: Countdown, now: Date) async throws -> ReflectionOutput {
        guard let apiKey = AppSecrets.openRouterAPIKey, !apiKey.isEmpty else {
            throw ReflectionError.missingAPIKey
        }

        if countdown.isFutureManifestation {
            return try await generateManifestation(for: countdown, now: now, apiKey: apiKey)
        }

        return try await performRequest(
            for: countdown,
            now: now,
            apiKey: apiKey
        )
    }

    private func generateManifestation(
        for countdown: Countdown,
        now: Date,
        apiKey: String
    ) async throws -> ReflectionOutput {
        let previousManifestation = PreviousManifestationSnapshot(from: countdown)
        let variationStyles = ManifestationVariationStyle.allCases.shuffled()
        let maximumAttempts = previousManifestation.hasContent ? 3 : 1

        for attempt in 0..<maximumAttempts {
            let context = ManifestationGenerationContext(
                previousManifestation: previousManifestation,
                attemptNumber: attempt + 1,
                variationSeed: UUID().uuidString,
                variationStyle: variationStyles[attempt % variationStyles.count]
            )

            let response = try await performRequest(
                for: countdown,
                now: now,
                apiKey: apiKey,
                manifestationContext: context
            )

            guard context.requiresVariationGuard else {
                return response
            }

            if !ManifestationSimilarity.isTooSimilar(response, to: previousManifestation) {
                return response
            }
        }

        throw ReflectionError.repeatedManifestation
    }

    private func performRequest(
        for countdown: Countdown,
        now: Date,
        apiKey: String,
        manifestationContext: ManifestationGenerationContext? = nil
    ) async throws -> ReflectionOutput {
        let systemPrompt = ReflectionPrompt.systemPrompt(
            for: countdown,
            now: now,
            manifestationContext: manifestationContext
        )
        let userPrompt = ReflectionPrompt.userPrompt(
            for: countdown,
            now: now,
            manifestationContext: manifestationContext
        )

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenRouterRequest(
            model: AppSecrets.openRouterModel,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: countdown.isFutureManifestation ? 0.95 : 0.7,
            responseFormat: ReflectionResponseSchema.responseFormat(for: countdown)
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReflectionError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReflectionError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let serviceMessage = try? JSONDecoder().decode(OpenRouterErrorResponse.self, from: data)
            throw ReflectionError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: serviceMessage?.error.message
            )
        }

        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.data(using: .utf8) else {
            throw ReflectionError.emptyResponse
        }

        return try ReflectionResponseSchema.decodeOutput(from: content, for: countdown)
    }
}

private enum ReflectionResponseSchema {
    static func responseFormat(for countdown: Countdown) -> OpenRouterRequest.ResponseFormat {
        if countdown.isFutureManifestation {
            return .init(
                type: "json_schema",
                jsonSchema: .init(
                    name: "moment_manifestation",
                    strict: true,
                    schema: .init(
                        type: "object",
                        properties: [
                            "instruction": .init(type: "string"),
                            "anchor": .init(type: "string")
                        ],
                        required: ["instruction", "anchor"],
                        additionalProperties: false
                    )
                )
            )
        }

        return .init(
            type: "json_schema",
            jsonSchema: .init(
                name: "moment_reflection",
                strict: true,
                schema: .init(
                    type: "object",
                    properties: [
                        "surface": .init(type: "string"),
                        "reflection": .init(type: "string"),
                        "guidance": .init(type: "string")
                    ],
                    required: ["surface", "reflection", "guidance"],
                    additionalProperties: false
                )
            )
        )
    }

    static func decodeOutput(from content: Data, for countdown: Countdown) throws -> ReflectionOutput {
        if countdown.isFutureManifestation {
            let manifestation = try JSONDecoder().decode(ManifestationOutput.self, from: content)
            return ReflectionOutput(
                surface: formattedManifestInstruction(manifestation.instruction),
                reflection: "",
                guidance: manifestation.anchor
            )
        }

        return try JSONDecoder().decode(ReflectionOutput.self, from: content)
    }

    private static func formattedManifestInstruction(_ instruction: String) -> String {
        let normalized = instruction
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return instruction }
        guard !normalized.contains("\n\n") else { return normalized }

        let sentenceBoundaryPattern = #"(?<=[.!?])\s+"#
        let regex = try? NSRegularExpression(pattern: sentenceBoundaryPattern)
        let fullRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let markedText = regex?.stringByReplacingMatches(
            in: normalized,
            options: [],
            range: fullRange,
            withTemplate: "<<<SPLIT>>>"
        ) ?? normalized

        let sentences = markedText
            .components(separatedBy: "<<<SPLIT>>>")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count >= 6 else { return normalized }

        let paragraphCount = 3
        let baseSize = sentences.count / paragraphCount
        let remainder = sentences.count % paragraphCount
        var paragraphs: [String] = []
        var currentIndex = 0

        for paragraphIndex in 0..<paragraphCount {
            let extraSentence = paragraphIndex < remainder ? 1 : 0
            let nextIndex = min(currentIndex + baseSize + extraSentence, sentences.count)
            let paragraph = sentences[currentIndex..<nextIndex].joined(separator: " ")
            paragraphs.append(paragraph)
            currentIndex = nextIndex
        }

        return paragraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

private enum ReflectionPrompt {
    static func systemPrompt(isPast: Bool) -> String {
        let sharedPrompt = loadPrompt(named: "system")
        let modePrompt = loadPrompt(named: isPast ? "past" : "future")

        switch (sharedPrompt, modePrompt) {
        case let (.some(shared), .some(mode)):
            return [shared, mode].joined(separator: "\n\n")
        case let (.some(shared), nil):
            return shared
        case let (nil, .some(mode)):
            return mode
        case (nil, nil):
            break
        }

        return """
        You are a reflective assistant inside a minimal iOS app.
        Use the provided title, date, current time, and optional context.
        Return JSON with `surface`, `reflection`, and `guidance`.
        Keep all fields concise, personal, calm, and specific to the moment.
        Avoid generic advice, clichés, and dramatic language.
        """
    }

    private static func loadPrompt(named name: String) -> String? {
        let searchLocations: [(String?, String?)] = [
            (name, nil),
            (name, "Prompts")
        ]

        for (resource, subdirectory) in searchLocations {
            if let url = Bundle.main.url(forResource: resource, withExtension: "txt", subdirectory: subdirectory),
               let prompt = try? String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines),
               !prompt.isEmpty {
                return prompt
            }
        }
        return nil
    }

    static func userPrompt(
        for countdown: Countdown,
        now: Date,
        manifestationContext: ManifestationGenerationContext? = nil
    ) -> String {
        var lines = ["Moment title: \(countdown.title)"]

        if countdown.isFutureManifestation {
            lines.append("Mode: Future manifestation (no fixed date)")
            lines.append("Today: \(now.smartFormatted)")
        } else {
            lines.append("Moment date: \(countdown.targetDate.smartFormatted)")
            lines.append("Today: \(now.smartFormatted)")
            lines.append("Days until: \(countdown.daysUntil(from: now))")
            lines.append("Days since: \(countdown.daysSince(from: now))")
        }

        if let detailsText = countdown.detailsText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !detailsText.isEmpty {
            lines.append("Context: \(detailsText)")
        }

        if countdown.isFutureManifestation, let manifestationContext {
            lines.append("Variation seed: \(manifestationContext.variationSeed)")
            lines.append("Variation focus: \(manifestationContext.variationStyle.userPromptFocus)")

            if manifestationContext.previousManifestation.hasContent {
                lines.append("Previous instruction: \(manifestationContext.previousManifestation.instruction)")
                lines.append("Previous anchor: \(manifestationContext.previousManifestation.anchor)")
                lines.append("Regeneration requirement: keep the same core desire, but write it with clearly different phrasing, rhythm, imagery, and sentence structure.")
                lines.append("Regeneration requirement: do not reuse distinctive phrases from the previous version.")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func systemPrompt(
        for countdown: Countdown,
        now: Date,
        manifestationContext: ManifestationGenerationContext? = nil
    ) -> String {
        if countdown.isFutureManifestation {
            let sharedPrompt = loadPrompt(named: "system")
            let manifestPrompt = loadPrompt(named: "manifest")
            let variationPrompt = manifestationVariationPrompt(for: manifestationContext)

            switch (sharedPrompt, manifestPrompt) {
            case let (.some(shared), .some(mode)):
                return [shared, mode, variationPrompt]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            case let (.some(shared), nil):
                return [shared, variationPrompt]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            case let (nil, .some(mode)):
                return [mode, variationPrompt]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            case (nil, nil):
                return systemPrompt(isPast: countdown.isExpired(at: now))
            }
        }

        return systemPrompt(isPast: countdown.isExpired(at: now))
    }

    private static func manifestationVariationPrompt(
        for context: ManifestationGenerationContext?
    ) -> String? {
        guard let context else { return nil }

        var lines = [
            "For this manifestation, emphasize \(context.variationStyle.systemPromptFocus).",
            "Let the voice feel fresh and materially different from other valid versions."
        ]

        if context.previousManifestation.hasContent {
            lines.append("This is a regeneration attempt. Preserve the intention, but change the wording, cadence, imagery, and structure from the previous version.")
            lines.append("Do not repeat distinctive phrases from the previous instruction or anchor.")
            lines.append("Attempt number: \(context.attemptNumber).")
        }

        return lines.joined(separator: "\n")
    }
}

private struct ManifestationGenerationContext {
    let previousManifestation: PreviousManifestationSnapshot
    let attemptNumber: Int
    let variationSeed: String
    let variationStyle: ManifestationVariationStyle

    var requiresVariationGuard: Bool {
        previousManifestation.hasContent
    }
}

private struct PreviousManifestationSnapshot {
    let instruction: String
    let anchor: String

    init(from countdown: Countdown) {
        instruction = countdown.reflectionSurfaceText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        anchor = countdown.reflectionGuidanceText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var hasContent: Bool {
        !instruction.isEmpty || !anchor.isEmpty
    }
}

private enum ManifestationVariationStyle: CaseIterable {
    case identityShift
    case everydayEvidence
    case embodiedCalm

    var userPromptFocus: String {
        switch self {
        case .identityShift:
            return "the identity of the person who already lives this reality"
        case .everydayEvidence:
            return "small, believable signs that this reality is already normal"
        case .embodiedCalm:
            return "grounded certainty in the body rather than dramatic intensity"
        }
    }

    var systemPromptFocus: String {
        switch self {
        case .identityShift:
            return "identity shift and self-concept"
        case .everydayEvidence:
            return "everyday evidence and naturalness"
        case .embodiedCalm:
            return "embodied calm and grounded certainty"
        }
    }
}

private enum ManifestationSimilarity {
    static func isTooSimilar(_ candidate: ReflectionOutput, to previous: PreviousManifestationSnapshot) -> Bool {
        guard previous.hasContent else { return false }

        let candidateCombined = normalize("\(candidate.surface) \(candidate.guidance)")
        let previousCombined = normalize("\(previous.instruction) \(previous.anchor)")

        guard !candidateCombined.isEmpty, !previousCombined.isEmpty else {
            return false
        }

        if candidateCombined == previousCombined {
            return true
        }

        return jaccardSimilarity(candidateCombined, previousCombined) >= 0.72
    }

    private static func normalize(_ text: String) -> Set<String> {
        let lowercase = text.lowercased()
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = lowercase
            .components(separatedBy: separators)
            .filter { $0.count > 2 }

        return Set(tokens)
    }

    private static func jaccardSimilarity(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        let intersectionCount = lhs.intersection(rhs).count
        let unionCount = lhs.union(rhs).count
        guard unionCount > 0 else { return 0 }
        return Double(intersectionCount) / Double(unionCount)
    }
}

private enum AppSecrets {
    static var openRouterAPIKey: String? {
        normalizedSecret(
            ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
                ?? Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String
        )
    }

    static var openRouterModel: String {
        let resolvedModel =
            ProcessInfo.processInfo.environment["OPENROUTER_MODEL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_MODEL") as? String

        let trimmed = resolvedModel?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmed,
           !trimmed.isEmpty,
           !trimmed.contains("$(") {
            return trimmed
        }

        return "openai/gpt-4o-mini"
    }

    private static func normalizedSecret(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.contains("$("),
              !placeholderSecrets.contains(trimmed) else {
            return nil
        }

        return trimmed
    }

    private static let placeholderSecrets: Set<String> = [
        "sk-or-v1-your-key",
        "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"
    ]
}

struct ReflectionOutput: Decodable {
    let surface: String
    let reflection: String
    let guidance: String
}

private struct ManifestationOutput: Decodable {
    let instruction: String
    let anchor: String
}

enum ReflectionError: Error {
    case missingAPIKey
    case emptyResponse
    case invalidResponse
    case repeatedManifestation
    case requestFailed(statusCode: Int, message: String?)
    case transport(Error)
}

extension ReflectionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AI generation is not configured. Add a real OPENROUTER_API_KEY in Moments/Config.xcconfig."
        case .emptyResponse:
            return "The AI service returned an empty response."
        case .invalidResponse:
            return "The AI service returned an invalid response."
        case .repeatedManifestation:
            return "Could not produce a fresh manifestation right now. Try again."
        case let .requestFailed(statusCode, message):
            if statusCode == 401 || statusCode == 403 {
                return "The OpenRouter key was rejected. Check OPENROUTER_API_KEY."
            }

            if let message, !message.isEmpty {
                return "AI request failed: \(message)"
            }

            return "AI request failed with status \(statusCode)."
        case .transport:
            return "Could not reach the AI service."
        }
    }
}

private struct OpenRouterRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
        let jsonSchema: JSONSchemaContainer

        enum CodingKeys: String, CodingKey {
            case type
            case jsonSchema = "json_schema"
        }
    }

    struct JSONSchemaContainer: Encodable {
        let name: String
        let strict: Bool
        let schema: JSONSchemaObject
    }

    struct JSONSchemaObject: Encodable {
        let type: String
        let properties: [String: JSONSchemaValue]
        let required: [String]
        let additionalProperties: Bool

        enum CodingKeys: String, CodingKey {
            case type, properties, required
            case additionalProperties = "additionalProperties"
        }
    }

    struct JSONSchemaValue: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
    }
}

private struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct OpenRouterErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }

    let error: ErrorBody
}
