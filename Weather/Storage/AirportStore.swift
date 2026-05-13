import Foundation

@MainActor
final class AirportStore {
    static let shared = AirportStore()

    private let airportsKey = "saved_airports"
    private let cacheDirectory: URL

    var airports: [String] {
        get { UserDefaults.standard.stringArray(forKey: airportsKey) ?? ["KPWM", "KAUS"] }
        set { UserDefaults.standard.set(newValue, forKey: airportsKey) }
    }

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appendingPathComponent("WeatherReports", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        if UserDefaults.standard.object(forKey: airportsKey) == nil {
            UserDefaults.standard.set(["KPWM", "KAUS"], forKey: airportsKey)
        }
    }

    func add(airport: String) {
        let id = airport.uppercased()
        guard !airports.contains(id) else { return }
        airports = airports + [id]
    }

    func remove(airport: String) {
        airports = airports.filter { $0 != airport.uppercased() }
    }

    // MARK: Cache

    func cache(_ report: WeatherReport, for identifier: String) {
        guard let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: cacheURL(for: identifier))
    }

    func cachedReport(for identifier: String) -> WeatherReport? {
        guard let data = try? Data(contentsOf: cacheURL(for: identifier)) else { return nil }
        return try? JSONDecoder().decode(WeatherReport.self, from: data)
    }

    private func cacheURL(for identifier: String) -> URL {
        cacheDirectory.appendingPathComponent("\(identifier.uppercased()).json")
    }
}
