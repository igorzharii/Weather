import Foundation

final class SettingsViewModel: ObservableObject {
    let intervals = RefreshInterval.allCases

    @Published var selectedInterval: RefreshInterval

    init() {
        selectedInterval = AutoRefreshSettings.shared.interval
    }

    func select(_ interval: RefreshInterval) {
        selectedInterval = interval
        AutoRefreshSettings.shared.interval = interval
        NotificationCenter.default.post(name: .autoRefreshSettingsChanged, object: nil)
    }
}
