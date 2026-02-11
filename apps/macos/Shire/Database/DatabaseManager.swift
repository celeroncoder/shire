import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    private(set) var dbPool: DatabasePool!

    private init() {}

    func setup() {
        do {
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let shireDir = appSupportURL.appendingPathComponent("Shire", isDirectory: true)
            try FileManager.default.createDirectory(at: shireDir, withIntermediateDirectories: true)

            let dbURL = shireDir.appendingPathComponent("shire.db")
            var config = Configuration()
            config.foreignKeysEnabled = true
            config.prepareDatabase { db in
                db.trace { print("SQL: \($0)") }
            }

            dbPool = try DatabasePool(path: dbURL.path, configuration: config)

            // Run migrations
            try runMigrations()

            print("Database initialized at: \(dbURL.path)")
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial") { db in
            try Schema.createInitialSchema(db)
        }

        try migrator.migrate(dbPool)
    }
}
