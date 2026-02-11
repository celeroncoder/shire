import Foundation
import GRDB

struct Artifact: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "artifacts"

    var id: String
    var sessionId: String
    var messageId: String
    var filePath: String
    var operation: String    // "create" | "write" | "edit"
    var createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, operation
        case sessionId = "session_id"
        case messageId = "message_id"
        case filePath = "file_path"
        case createdAt = "created_at"
    }

    init(id: String = UUIDv7.generate(), sessionId: String, messageId: String, filePath: String, operation: String) {
        self.id = id
        self.sessionId = sessionId
        self.messageId = messageId
        self.filePath = filePath
        self.operation = operation
        self.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
    }
}
