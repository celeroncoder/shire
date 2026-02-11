import Foundation
import GRDB

final class SessionRepository {
    static let shared = SessionRepository()

    private var dbPool: DatabasePool { DatabaseManager.shared.dbPool }

    private init() {}

    func listByWorkspace(workspaceId: String) -> [Session] {
        do {
            return try dbPool.read { db in
                try Session
                    .filter(Column("workspace_id") == workspaceId)
                    .order(Column("updated_at").desc)
                    .fetchAll(db)
            }
        } catch {
            print("Error listing sessions: \(error)")
            return []
        }
    }

    func getById(id: String) -> Session? {
        do {
            return try dbPool.read { db in
                try Session.fetchOne(db, key: id)
            }
        } catch {
            print("Error fetching session \(id): \(error)")
            return nil
        }
    }

    @discardableResult
    func create(workspaceId: String, title: String? = nil) -> Session {
        let session = Session(workspaceId: workspaceId, title: title)
        do {
            try dbPool.write { db in
                try session.insert(db)
            }
        } catch {
            print("Error creating session: \(error)")
        }
        return session
    }

    @discardableResult
    func rename(id: String, title: String) -> Session? {
        do {
            return try dbPool.write { db -> Session? in
                guard var session = try Session.fetchOne(db, key: id) else { return nil }
                session.title = title
                session.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
                try session.update(db)
                return session
            }
        } catch {
            print("Error renaming session \(id): \(error)")
            return nil
        }
    }

    func updateClaudeSessionId(id: String, claudeSessionId: String) {
        do {
            try dbPool.write { db in
                guard var session = try Session.fetchOne(db, key: id) else { return }
                session.claudeSessionId = claudeSessionId
                session.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
                try session.update(db)
            }
        } catch {
            print("Error updating claude session id: \(error)")
        }
    }

    func touch(id: String) {
        do {
            try dbPool.write { db in
                guard var session = try Session.fetchOne(db, key: id) else { return }
                session.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
                try session.update(db)
            }
        } catch {
            print("Error touching session \(id): \(error)")
        }
    }

    func delete(id: String) {
        do {
            try dbPool.write { db in
                _ = try Session.deleteOne(db, key: id)
            }
        } catch {
            print("Error deleting session \(id): \(error)")
        }
    }
}
