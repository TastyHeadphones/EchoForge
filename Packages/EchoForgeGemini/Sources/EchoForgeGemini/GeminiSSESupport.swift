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

struct GeminiSSEJSONFramer {
    private var buffer = Data()
    private let maxBufferBytes: Int

    init(maxBufferBytes: Int = 1_000_000) {
        self.maxBufferBytes = maxBufferBytes
    }

    mutating func append(_ text: String) throws -> [Data] {
        let incomingCount = text.utf8.count
        if buffer.count + incomingCount > maxBufferBytes {
            buffer.removeAll(keepingCapacity: true)
            throw GeminiSSEJSONFramerError.bufferExceededLimit
        }

        buffer.append(contentsOf: text.utf8)
        return frame()
    }

    mutating func finish() -> Data? {
        let trimmed = Data(buffer.drop(while: { $0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D }))
        buffer.removeAll(keepingCapacity: false)
        return trimmed.isEmpty ? nil : trimmed
    }

    private mutating func frame() -> [Data] {
        var frames: [Data] = []
        var state = ScanState()

        var index = 0
        while index < buffer.count {
            let byte = buffer[index]
            if state.startIndex == nil {
                handleByteOutsideObject(byte, index: index, state: &state)
            } else {
                handleByteInsideObject(byte, index: index, state: &state, frames: &frames)
            }
            index += 1
        }

        if state.consumablePrefixEnd > 0 {
            buffer.removeSubrange(0..<state.consumablePrefixEnd)
        }

        return frames
    }

    private struct ScanState {
        var startIndex: Int?
        var depth = 0
        var isInsideString = false
        var isEscaping = false
        var consumablePrefixEnd = 0
    }

    private func handleByteOutsideObject(_ byte: UInt8, index: Int, state: inout ScanState) {
        if isWhitespace(byte) {
            state.consumablePrefixEnd = index + 1
            return
        }

        if byte == 0x7B || byte == 0x5B { // '{' or '['
            state.startIndex = index
            state.depth = 1
            state.isInsideString = false
            state.isEscaping = false
            return
        }

        state.consumablePrefixEnd = index + 1
    }

    private func handleByteInsideObject(_ byte: UInt8, index: Int, state: inout ScanState, frames: inout [Data]) {
        if state.isInsideString {
            handleByteInsideString(byte, state: &state)
        } else {
            handleByteOutsideString(byte, index: index, state: &state, frames: &frames)
        }
    }

    private func handleByteInsideString(_ byte: UInt8, state: inout ScanState) {
        if state.isEscaping {
            state.isEscaping = false
        } else if byte == 0x5C { // '\\'
            state.isEscaping = true
        } else if byte == 0x22 { // '"'
            state.isInsideString = false
        }
    }

    private func handleByteOutsideString(_ byte: UInt8, index: Int, state: inout ScanState, frames: inout [Data]) {
        if byte == 0x22 { // '"'
            state.isInsideString = true
            return
        }

        if byte == 0x7B || byte == 0x5B { // '{' or '['
            state.depth += 1
            return
        }

        if byte == 0x7D || byte == 0x5D { // '}' or ']'
            state.depth -= 1
            guard state.depth == 0, let start = state.startIndex else { return }

            let endIndex = index + 1
            frames.append(buffer.subdata(in: start..<endIndex))
            state.startIndex = nil
            state.consumablePrefixEnd = endIndex
        }
    }

    private func isWhitespace(_ byte: UInt8) -> Bool {
        // space, tab, newline, carriage return
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }
}

enum GeminiSSEJSONFramerError: LocalizedError, Sendable {
    case bufferExceededLimit
    case trailingIncompleteJSON

    var errorDescription: String? {
        switch self {
        case .bufferExceededLimit:
            return "Gemini SSE JSON buffer exceeded safety limit."
        case .trailingIncompleteJSON:
            return "Gemini SSE ended with a partial JSON message."
        }
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
    private static let maxLoggedChars = 2_048

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
