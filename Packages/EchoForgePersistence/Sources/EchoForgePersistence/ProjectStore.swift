import Foundation
import EchoForgeCore

public actor ProjectStore: ProjectStoring {
    private let fileManager: FileManager
    private let rootURL: URL

    public init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? Self.defaultRootURL(fileManager: fileManager)
    }

    public func loadAll() async throws -> [PodcastProject] {
        try ensureDirectories()

        let urls = try fileManager.contentsOfDirectory(
            at: projectsDirectoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension.lowercased() == "json" }

        var projects: [PodcastProject] = []
        projects.reserveCapacity(urls.count)

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let project = try EchoForgeJSON.decoder().decode(PodcastProject.self, from: data)
                projects.append(project)
            } catch {
                // If a single file is corrupted, keep going.
                continue
            }
        }

        return projects.sorted { $0.createdAt > $1.createdAt }
    }

    public func load(id: UUID) async throws -> PodcastProject {
        try ensureDirectories()

        let url = projectFileURL(id: id)
        let data = try Data(contentsOf: url)
        return try EchoForgeJSON.decoder().decode(PodcastProject.self, from: data)
    }

    public func save(_ project: PodcastProject) async throws {
        try ensureDirectories()

        let url = projectFileURL(id: project.id)
        let data = try EchoForgeJSON.encoder(prettyPrinted: true).encode(project)
        try data.write(to: url, options: [.atomic])
    }

    public func delete(id: UUID) async throws {
        try ensureDirectories()

        let url = projectFileURL(id: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func ensureDirectories() throws {
        if !fileManager.fileExists(atPath: projectsDirectoryURL.path) {
            try fileManager.createDirectory(at: projectsDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private var projectsDirectoryURL: URL {
        rootURL.appendingPathComponent("projects", isDirectory: true)
    }

    private func projectFileURL(id: UUID) -> URL {
        projectsDirectoryURL.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    private static func defaultRootURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("EchoForge", isDirectory: true)
    }
}
