import Foundation
import EchoForgeCore
import EchoForgePersistence

actor ProjectAutosaver {
    private let store: any ProjectStoring
    private var pending: PodcastProject?
    private var task: Task<Void, Never>?

    init(store: any ProjectStoring) {
        self.store = store
    }

    func scheduleSave(_ project: PodcastProject, after delay: Duration = .seconds(1)) {
        pending = project
        task?.cancel()

        task = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard let pending else { return }
            try? await store.save(pending)
        }
    }

    func flush() async {
        task?.cancel()
        task = nil

        if let pending {
            try? await store.save(pending)
        }

        self.pending = nil
    }
}
