import Foundation
import GRDB

final class ArtifactRepository {
    static let shared = ArtifactRepository()

    private var dbPool: DatabasePool { DatabaseManager.shared.dbPool }

    private init() {}

    func listBySession(sessionId: String) -> [Artifact] {
        do {
            return try dbPool.read { db in
                try Artifact
                    .filter(Column("session_id") == sessionId)
                    .order(Column("created_at").asc)
                    .fetchAll(db)
            }
        } catch {
            print("Error listing artifacts: \(error)")
            return []
        }
    }

    @discardableResult
    func create(sessionId: String, messageId: String, filePath: String, operation: String) -> Artifact {
        let artifact = Artifact(sessionId: sessionId, messageId: messageId, filePath: filePath, operation: operation)
        do {
            try dbPool.write { db in
                try artifact.insert(db)
            }
        } catch {
            print("Error creating artifact: \(error)")
        }
        return artifact
    }

    /// Upsert: create only if no artifact exists for (session_id, file_path)
    @discardableResult
    func createIfNotExists(sessionId: String, messageId: String, filePath: String, operation: String) -> Artifact? {
        do {
            return try dbPool.write { db -> Artifact? in
                let exists = try Artifact
                    .filter(Column("session_id") == sessionId && Column("file_path") == filePath)
                    .fetchOne(db)
                if exists != nil { return nil }
                let artifact = Artifact(sessionId: sessionId, messageId: messageId, filePath: filePath, operation: operation)
                try artifact.insert(db)
                return artifact
            }
        } catch {
            print("Error in createIfNotExists artifact: \(error)")
            return nil
        }
    }
}
