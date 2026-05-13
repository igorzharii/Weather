import Combine
import UIKit

@MainActor
final class AirportListViewModel {

    // MARK: - Outputs

    @Published private(set) var airports: [String] = []

    // MARK: - Navigation callbacks

    var onShowDetail: ((String) -> Void)?
    var onShowSettings: (() -> Void)?

    // MARK: - Private

    private let store: AirportStore
    private let service: WeatherServiceProtocol
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(store: AirportStore = .shared, service: WeatherServiceProtocol = WeatherService.shared) {
        self.store = store
        self.service = service
        airports = store.airports
        startRefreshTimer()
        fetchAll()

        NotificationCenter.default.publisher(for: .autoRefreshSettingsChanged)
            .sink { [weak self] _ in self?.startRefreshTimer() }
            .store(in: &cancellables)
    }

    deinit { refreshTimer?.invalidate() }

    // MARK: - Actions

    func add(identifier: String) {
        let id = identifier.trimmingCharacters(in: .whitespaces).uppercased()
        guard !id.isEmpty else { return }
        store.add(airport: id)
        reload()
        onShowDetail?(id)
    }

    func remove(at index: Int) {
        guard airports.indices.contains(index) else { return }
        store.remove(airport: airports[index])
        reload()
    }

    func select(at index: Int) {
        guard airports.indices.contains(index) else { return }
        onShowDetail?(airports[index])
    }

    func requestSettings() {
        onShowSettings?()
    }

    func refresh() {
        reload()
    }

    // MARK: - Display helpers

    func subtitle(for identifier: String) -> (text: String, color: UIColor)? {
        guard let conditions = store.cachedReport(for: identifier)?.report.conditions else { return nil }
        let temp = conditions.tempC.map { String(format: "%.0f°C", $0) }
        let text = [conditions.flightRules, temp].compactMap { $0 }.joined(separator: " · ")
        guard !text.isEmpty else { return nil }
        return (text, flightRulesColor(conditions.flightRules))
    }

    // MARK: - Private helpers

    private func reload() {
        airports = store.airports
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        let interval = AutoRefreshSettings.shared.interval
        guard interval != .off else { return }
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(interval.rawValue),
            repeats: true
        ) { [weak self] _ in self?.refreshAll() }
    }

    private func refreshAll() {
        fetchAll()
    }

    private func fetchAll() {
        let ids = airports
        Task {
            for id in ids {
                guard let report = try? await service.fetchWeather(for: id) else { continue }
                store.cache(report, for: id)
                reload()
            }
        }
    }

    private func flightRulesColor(_ rules: String?) -> UIColor {
        switch rules {
        case "VFR":  return .systemGreen
        case "MVFR": return .systemBlue
        case "IFR":  return .systemRed
        case "LIFR": return .systemPurple
        default:     return .secondaryLabel
        }
    }
}
