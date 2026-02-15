import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct ZipFileDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.zip] }

    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
