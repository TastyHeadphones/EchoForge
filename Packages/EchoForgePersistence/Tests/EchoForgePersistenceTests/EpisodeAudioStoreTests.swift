import XCTest
@testable import EchoForgePersistence

final class EpisodeAudioStoreTests: XCTestCase {
    func testWriteWAVCreatesFileWithRIFFHeader() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = EpisodeAudioStore(rootURL: root)

        let projectID = UUID()
        let episodeID = UUID()

        // 100ms of silence: 24_000 Hz, mono, 16-bit => 2400 samples => 4800 bytes.
        let pcm = Data(repeating: 0, count: 4_800)
        let url = try await store.writeWAV(
            pcmData: pcm,
            projectID: projectID,
            episodeID: episodeID,
            fileName: nil,
            format: WAVFormat(sampleRateHz: 24_000, channels: 1, bitsPerSample: 16)
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let written = try Data(contentsOf: url)
        let header = String(data: written.prefix(4), encoding: .utf8)
        XCTAssertEqual(header, "RIFF")
    }
}
