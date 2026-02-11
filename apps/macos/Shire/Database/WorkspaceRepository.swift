import Foundation
import GRDB

final class WorkspaceRepository {
    static let shared = WorkspaceRepository()

    private var dbPool: DatabasePool { DatabaseManager.shared.dbPool }

    private init() {}

    func list() -> [Workspace] {
        do {
            return try dbPool.read { db in
                try Workspace
                    .order(Column("updated_at").desc)
                    .fetchAll(db)
            }
        } catch {
            print("Error listing workspaces: \(error)")
            return []
        }
    }

    func getById(id: String) -> Workspace? {
        do {
            return try dbPool.read { db in
                try Workspace.fetchOne(db, key: id)
            }
        } catch {
            print("Error fetching workspace \(id): \(error)")
            return nil
        }
    }

    @discardableResult
    func create(name: String, path: String) -> Workspace {
        let workspace = Workspace(name: name, path: path)
        do {
            try dbPool.write { db in
                try workspace.insert(db)
            }
        } catch {
            print("Error creating workspace: \(error)")
        }
        return workspace
    }

    @discardableResult
    func update(id: String, name: String) -> Workspace? {
        do {
            return try dbPool.write { db -> Workspace? in
                guard var workspace = try Workspace.fetchOne(db, key: id) else { return nil }
                workspace.name = name
                workspace.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
                try workspace.update(db)
                return workspace
            }
        } catch {
            print("Error updating workspace \(id): \(error)")
            return nil
        }
    }

    func delete(id: String) {
        do {
            try dbPool.write { db in
                _ = try Workspace.deleteOne(db, key: id)
            }
        } catch {
            print("Error deleting workspace \(id): \(error)")
        }
    }
}
