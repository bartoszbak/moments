import Foundation

final class ReflectionService {
    static let shared = ReflectionService()

    private init() {}

    func generateReflection(for countdown: Countdown, now: Date) async throws -> ReflectionOutput {
        guard let apiKey = AppSecrets.openRouterAPIKey, !apiKey.isEmpty else {
            throw ReflectionError.missingAPIKey
        }

        let systemPrompt = ReflectionPrompt.systemPrompt(for: countdown, now: now)
        let userPrompt = ReflectionPrompt.userPrompt(for: countdown, now: now)

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
            temperature: 0.7,
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
                surface: manifestation.instruction,
                reflection: "",
                guidance: manifestation.anchor
            )
        }

        return try JSONDecoder().decode(ReflectionOutput.self, from: content)
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

    static func userPrompt(for countdown: Countdown, now: Date) -> String {
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

        return lines.joined(separator: "\n")
    }

    static func systemPrompt(for countdown: Countdown, now: Date) -> String {
        if countdown.isFutureManifestation {
            let sharedPrompt = loadPrompt(named: "system")
            let manifestPrompt = loadPrompt(named: "manifest")

            switch (sharedPrompt, manifestPrompt) {
            case let (.some(shared), .some(mode)):
                return [shared, mode].joined(separator: "\n\n")
            case let (.some(shared), nil):
                return shared
            case let (nil, .some(mode)):
                return mode
            case (nil, nil):
                return systemPrompt(isPast: countdown.isExpired(at: now))
            }
        }

        return systemPrompt(isPast: countdown.isExpired(at: now))
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
