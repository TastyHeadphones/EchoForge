import Foundation

struct PodcastNDJSONStreamDecoder {
    private var buffer: String = ""
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    mutating func append(_ text: String) throws -> [PodcastStreamEvent] {
        buffer.append(text)
        return try drainCompleteLines()
    }

    mutating func finish() throws -> [PodcastStreamEvent] {
        // If the stream ends without a trailing newline, allow one final decode attempt.
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            buffer = ""
            return []
        }

        buffer = ""
        return [try decodeLine(trimmed)]
    }

    private mutating func drainCompleteLines() throws -> [PodcastStreamEvent] {
        var events: [PodcastStreamEvent] = []

        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[..<newlineRange.lowerBound])
            buffer.removeSubrange(..<newlineRange.upperBound)

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            events.append(try decodeLine(trimmed))
        }

        return events
    }

    private func decodeLine(_ line: String) throws -> PodcastStreamEvent {
        let data = Data(line.utf8)
        return try decoder.decode(PodcastStreamEvent.self, from: data)
    }
}
