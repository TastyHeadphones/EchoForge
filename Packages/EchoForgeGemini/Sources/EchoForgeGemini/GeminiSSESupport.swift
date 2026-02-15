import Foundation

struct SSEDataAccumulator {
    private var dataLines: [String] = []

    mutating func ingest(line: String) -> String? {
        let normalizedLine = line.trimmingCharacters(in: .newlines)

        if normalizedLine.hasPrefix("data:") {
            let payload = normalizedLine.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            dataLines.append(payload)
            return nil
        }

        // Blank line indicates end of SSE event. Some servers use CRLF which may leave "\r" behind.
        if normalizedLine.trimmingCharacters(in: .whitespaces).isEmpty {
            return flush()
        }

        // Ignore other SSE fields (event:, id:, retry:, comments, etc.).
        return nil
    }

    mutating func flush() -> String? {
        guard !dataLines.isEmpty else {
            return nil
        }

        let payload = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        return payload
    }
}

enum GeminiWireLogger {
    /// To print SSE payloads in Xcode's console, set `ECHOFORGE_LOG_GEMINI=1` in the run scheme environment.
    static let isEnabled: Bool = {
#if DEBUG
        let value = ProcessInfo.processInfo.environment["ECHOFORGE_LOG_GEMINI"] ?? ""
        return value == "1" || value.lowercased() == "true"
#else
        return false
#endif
    }()

    private static let maxLoggedChars = 8_192

    static func logSSEPayload(index: Int, payload: String) {
        guard isEnabled else { return }
        print("[Gemini SSE #\(index)] \(clip(payload))")
    }

    static func logSSEDecodeFailure(payload: String, error: Error) {
        print("[Gemini SSE decode error] \(error)\nPayload preview:\n\(clip(payload))")
    }

    static func logHTTPError(statusCode: Int, body: String?) {
        guard isEnabled else { return }
        if let body, !body.isEmpty {
            print("[Gemini HTTP \(statusCode)] Body preview:\n\(clip(body))")
        } else {
            print("[Gemini HTTP \(statusCode)] Empty body")
        }
    }

    private static func clip(_ text: String) -> String {
        if text.count <= maxLoggedChars {
            return text
        }
        let prefix = text.prefix(maxLoggedChars)
        return "\(prefix)\n… (truncated, total chars: \(text.count))"
    }
}
