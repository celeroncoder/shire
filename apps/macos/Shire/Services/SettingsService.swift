import Foundation

/// Permission modes for Claude Code subprocess
enum PermissionMode: String, CaseIterable {
    case `default` = "default"
    case plan = "plan"
    case acceptEdits = "acceptEdits"
    case bypassAll = "bypassPermissions"

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .plan: return "Plan"
        case .acceptEdits: return "Accept Edits"
        case .bypassAll: return "Bypass All"
        }
    }

    var iconName: String {
        switch self {
        case .default: return "hand.raised"
        case .plan: return "list.clipboard"
        case .acceptEdits: return "checkmark.shield"
        case .bypassAll: return "bolt.shield"
        }
    }

    /// Whether the user should be prompted for each file edit
    var requiresApproval: Bool {
        return self == .default || self == .plan
    }
}

/// Settings management service
final class SettingsService {
    static let shared = SettingsService()

    private init() {}

    /// Current model selection (defaults to "sonnet")
    var model: String {
        return getSetting(key: "model") ?? "sonnet"
    }

    /// Current permission mode (defaults to "acceptEdits")
    var permissionMode: PermissionMode {
        guard let raw = getSetting(key: "permission_mode"),
              let mode = PermissionMode(rawValue: raw) else {
            return .acceptEdits
        }
        return mode
    }

    func setPermissionMode(_ mode: PermissionMode) {
        setSetting(key: "permission_mode", value: mode.rawValue)
    }

    func getSetting(key: String) -> String? {
        return SettingsRepository.shared.get(key: key)
    }

    func setSetting(key: String, value: String?) {
        SettingsRepository.shared.set(key: key, value: value)
    }

    func getAllSettings() -> [String: String?] {
        return SettingsRepository.shared.getAll()
    }

    func setMany(_ settings: [String: String?]) {
        SettingsRepository.shared.setMany(settings)
    }
}
