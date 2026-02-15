import Foundation
import OSLog

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

    private static let logger = Logger(subsystem: "EchoForge", category: "GeminiWire")
    private static let maxLoggedChars = 8_192

    static func logSSEPayload(index: Int, payload: String) {
        guard isEnabled else { return }
        logger.info("SSE #\(index): \(clip(payload), privacy: .public)")
    }

    static func logSSEDecodeFailure(payload: String, error: Error) {
        if isEnabled {
            logger.error("SSE decode error: \(String(describing: error), privacy: .public)")
            logger.error("Payload preview: \(clip(payload), privacy: .public)")
        } else {
            logger.error("SSE decode error: \(String(describing: error), privacy: .public)")
            logger.error("Set ECHOFORGE_LOG_GEMINI=1 to log payload preview.")
        }
    }

    static func logHTTPError(statusCode: Int, body: String?) {
        if isEnabled, let body, !body.isEmpty {
            logger.error("HTTP \(statusCode) body preview: \(clip(body), privacy: .public)")
        } else {
            logger.error("HTTP \(statusCode). Set ECHOFORGE_LOG_GEMINI=1 to log response body.")
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
