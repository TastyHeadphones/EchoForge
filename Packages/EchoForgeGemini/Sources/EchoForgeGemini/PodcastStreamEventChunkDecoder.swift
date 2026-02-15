import Foundation

struct PodcastStreamEventChunkDecoder {
    private var framer: GeminiSSEJSONFramer
    private let decoder: JSONDecoder

    private(set) var decodedEventCount: Int = 0

    init(decoder: JSONDecoder = JSONDecoder(), maxBufferBytes: Int = 2_000_000) {
        self.decoder = decoder
        self.framer = GeminiSSEJSONFramer(maxBufferBytes: maxBufferBytes)
    }

    mutating func append(_ text: String) throws -> [PodcastStreamEvent] {
        let frames = try framer.append(text)
        return decode(frames: frames)
    }

    mutating func finish() throws -> [PodcastStreamEvent] {
        let frames = try framer.append("")
        let events = decode(frames: frames)

        if let trailing = framer.finish() {
            let preview = String(data: trailing, encoding: .utf8) ?? "<non-utf8 bytes: \(trailing.count)>"
            GeminiWireLogger.logModelOutputDecodeFailure(
                chunkPreview: preview,
                error: GeminiSSEJSONFramerError.trailingIncompleteJSON
            )
        }

        return events
    }

    private mutating func decode(frames: [Data]) -> [PodcastStreamEvent] {
        var events: [PodcastStreamEvent] = []

        for frame in frames {
            guard frame.first == UInt8(ascii: "{") else {
                continue
            }

            do {
                let event = try decoder.decode(PodcastStreamEvent.self, from: frame)
                decodedEventCount += 1
                events.append(event)
            } catch {
                let preview = String(data: frame, encoding: .utf8) ?? "<non-utf8 bytes: \(frame.count)>"
                GeminiWireLogger.logModelOutputDecodeFailure(chunkPreview: preview, error: error)
            }
        }

        return events
    }
}
