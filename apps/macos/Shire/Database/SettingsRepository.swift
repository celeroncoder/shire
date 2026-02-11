import Foundation
import GRDB

final class SettingsRepository {
    static let shared = SettingsRepository()

    private var dbPool: DatabasePool { DatabaseManager.shared.dbPool }

    private init() {}

    func getAll() -> [String: String?] {
        do {
            let rows = try dbPool.read { db in
                try SettingsRow.fetchAll(db)
            }
            var result: [String: String?] = [:]
            for row in rows {
                result[row.key] = row.value
            }
            return result
        } catch {
            print("Error getting settings: \(error)")
            return [:]
        }
    }

    func get(key: String) -> String? {
        do {
            return try dbPool.read { db in
                try SettingsRow.fetchOne(db, key: key)?.value
            }
        } catch {
            print("Error getting setting \(key): \(error)")
            return nil
        }
    }

    func set(key: String, value: String?) {
        do {
            try dbPool.write { db in
                let row = SettingsRow(key: key, value: value)
                try row.save(db)
            }
        } catch {
            print("Error setting \(key): \(error)")
        }
    }

    func setMany(_ map: [String: String?]) {
        do {
            try dbPool.write { db in
                for (key, value) in map {
                    let row = SettingsRow(key: key, value: value)
                    try row.save(db)
                }
            }
        } catch {
            print("Error setting multiple settings: \(error)")
        }
    }
}
