import Foundation
import GRDB

struct Workspace: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "workspaces"

    var id: String
    var name: String
    var path: String
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, path
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String = UUIDv7.generate(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        self.createdAt = now
        self.updatedAt = now
    }
}
