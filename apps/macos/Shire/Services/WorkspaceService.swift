import Foundation

/// Workspace and session CRUD orchestration
final class WorkspaceService {
    static let shared = WorkspaceService()

    private init() {}

    @discardableResult
    func createWorkspace(name: String, path: String) -> Workspace {
        let workspace = WorkspaceRepository.shared.create(name: name, path: path)
        NotificationCenter.default.post(name: .workspacesChanged, object: nil)
        return workspace
    }

    func renameWorkspace(id: String, name: String) {
        WorkspaceRepository.shared.update(id: id, name: name)
        NotificationCenter.default.post(name: .workspacesChanged, object: nil)
    }

    func deleteWorkspace(id: String) {
        WorkspaceRepository.shared.delete(id: id)
        NotificationCenter.default.post(name: .workspacesChanged, object: nil)
    }

    @discardableResult
    func createSession(workspaceId: String, title: String? = nil) -> Session {
        let session = SessionRepository.shared.create(workspaceId: workspaceId, title: title)
        NotificationCenter.default.post(name: .sessionsChanged, object: nil)
        return session
    }

    func renameSession(id: String, title: String) {
        SessionRepository.shared.rename(id: id, title: title)
        NotificationCenter.default.post(name: .sessionsChanged, object: nil)
    }

    func deleteSession(id: String) {
        SessionRepository.shared.delete(id: id)
        NotificationCenter.default.post(name: .sessionsChanged, object: nil)
    }
}
