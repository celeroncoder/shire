import Foundation
import GRDB

struct SettingsRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "settings"

    var key: String
    var value: String?
}
