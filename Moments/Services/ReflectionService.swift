import Foundation

final class ReflectionService {
    static let shared = ReflectionService()

    private init() {}

    func generateReflection(for countdown: Countdown, now: Date) async throws -> ReflectionOutput {
        guard let apiKey = AppSecrets.openRouterAPIKey, !apiKey.isEmpty else {
            throw ReflectionError.missingAPIKey
        }

        let isPast = countdown.isExpired(at: now)
        let systemPrompt = ReflectionPrompt.systemPrompt(isPast: isPast)
        let userPrompt = ReflectionPrompt.userPrompt(for: countdown, now: now)

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenRouterRequest(
            model: AppSecrets.openRouterModel,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            responseFormat: .init(
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
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.data(using: .utf8) else {
            throw ReflectionError.emptyResponse
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
        var lines = [
            "Moment title: \(countdown.title)",
            "Moment date: \(countdown.targetDate.smartFormatted)",
            "Today: \(now.smartFormatted)",
            "Days until: \(countdown.daysUntil(from: now))",
            "Days since: \(countdown.daysSince(from: now))"
        ]

        if let detailsText = countdown.detailsText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !detailsText.isEmpty {
            lines.append("Context: \(detailsText)")
        }

        return lines.joined(separator: "\n")
    }
}

private enum AppSecrets {
    static var openRouterAPIKey: String? {
        ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String
    }

    static var openRouterModel: String {
        (ProcessInfo.processInfo.environment["OPENROUTER_MODEL"]
         ?? Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_MODEL") as? String)
            ?? "openai/gpt-4o-mini"
    }
}

struct ReflectionOutput: Decodable {
    let surface: String
    let reflection: String
    let guidance: String
}

enum ReflectionError: Error {
    case missingAPIKey
    case emptyResponse
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
