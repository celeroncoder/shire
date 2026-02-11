import Foundation
import GRDB

struct Session: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "sessions"

    var id: String
    var workspaceId: String
    var claudeSessionId: String?
    var title: String?
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, title
        case workspaceId = "workspace_id"
        case claudeSessionId = "claude_session_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String = UUIDv7.generate(), workspaceId: String, claudeSessionId: String? = nil, title: String? = nil) {
        self.id = id
        self.workspaceId = workspaceId
        self.claudeSessionId = claudeSessionId
        self.title = title
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        self.createdAt = now
        self.updatedAt = now
    }
}
