import Foundation

enum RefreshInterval: Int, CaseIterable {
    case off = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case thirtyMinutes = 1800

    var title: String {
        switch self {
        case .off: return "Off"
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .thirtyMinutes: return "30 minutes"
        }
    }
}

final class AutoRefreshSettings {
    static let shared = AutoRefreshSettings()
    private let key = "auto_refresh_interval"

    var interval: RefreshInterval {
        get { RefreshInterval(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .off }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
