import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct ZipFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.zip] }

    public var url: URL

    public static func placeholder() -> ZipFileDocument {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoForge-Placeholder")
            .appendingPathExtension("zip")

        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }

        return ZipFileDocument(url: url)
    }

    public init(url: URL) {
        self.url = url
    }

    public init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
        try data.write(to: temp, options: [.atomic])
        self.url = temp
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: [.immediate])
    }
}
