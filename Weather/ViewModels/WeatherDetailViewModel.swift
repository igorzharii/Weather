import Combine
import Foundation

// MARK: - Display types (ViewModel → ViewController contract)

enum WeatherDisplayMode: Int {
    case conditions = 0
    case forecast   = 1
}

struct WeatherSection {
    let title: String
    let rows: [WeatherRow]
}

struct WeatherRow {
    let title: String
    let value: String
}

enum WeatherDisplayContent {
    case loading
    case error(String)
    case loaded(rawText: String?, sections: [WeatherSection])
}

// MARK: - ViewModel

@MainActor
final class WeatherDetailViewModel {

    let identifier: String

    @Published private(set) var displayContent: WeatherDisplayContent = .loading
    @Published var mode: WeatherDisplayMode = .conditions

    private let service: WeatherServiceProtocol
    private let store: AirportStore
    private var report: WeatherReport?
    private var fetchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        identifier: String,
        service: WeatherServiceProtocol = WeatherService.shared,
        store: AirportStore = .shared
    ) {
        self.identifier = identifier
        self.service = service
        self.store = store

        if let cached = store.cachedReport(for: identifier) {
            report = cached
            displayContent = Self.buildContent(report: cached, mode: .conditions)
        }

        $mode
            .dropFirst()
            .sink { [weak self] newMode in
                guard let self, let report = self.report else { return }
                self.displayContent = Self.buildContent(report: report, mode: newMode)
            }
            .store(in: &cancellables)
    }

    deinit { fetchTask?.cancel() }

    // MARK: - Actions

    func fetch() {
        fetchTask?.cancel()
        if report == nil { displayContent = .loading }

        fetchTask = Task {
            do {
                let result = try await service.fetchWeather(for: identifier)
                guard !Task.isCancelled else { return }
                store.cache(result, for: identifier)
                report = result
                displayContent = Self.buildContent(report: result, mode: mode)
            } catch {
                guard !Task.isCancelled else { return }
                if report == nil {
                    displayContent = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Content building

    private static func buildContent(report: WeatherReport, mode: WeatherDisplayMode) -> WeatherDisplayContent {
        switch mode {
        case .conditions:
            return .loaded(rawText: report.report.conditions?.text,
                           sections: conditionSections(report.report.conditions))
        case .forecast:
            return .loaded(rawText: report.report.forecast?.text,
                           sections: forecastSections(report.report.forecast))
        }
    }

    // MARK: Conditions

    private static func conditionSections(_ c: Conditions?) -> [WeatherSection] {
        guard let c else {
            return [WeatherSection(title: "", rows: [WeatherRow(title: "No conditions available", value: "")])]
        }

        var sections: [WeatherSection] = []

        sections.append(WeatherSection(title: "Overview", rows: [
            WeatherRow(title: "Flight Rules", value: c.flightRules ?? "—"),
            WeatherRow(title: "Station",      value: c.ident ?? "—"),
            WeatherRow(title: "Issued",       value: formatDate(c.dateIssued)),
            c.elevationFt.map { WeatherRow(title: "Elevation", value: fmt("%.0f ft", $0)) }
        ].compactMap { $0 }))

        sections.append(WeatherSection(title: "Temperature", rows: [
            WeatherRow(title: "Temp",        value: c.tempC.map { String(format: "%.1f°C  /  %.1f°F", $0, $0 * 9/5 + 32) } ?? "—"),
            WeatherRow(title: "Dewpoint",    value: c.dewpointC.map { fmt("%.1f°C", $0) } ?? "—"),
            WeatherRow(title: "Humidity",    value: c.relativeHumidity.map { fmt("%.0f%%", $0) } ?? "—"),
            WeatherRow(title: "Density Alt", value: c.densityAltitudeFt.map { fmt("%.0f ft", $0) } ?? "—")
        ]))

        sections.append(WeatherSection(title: "Wind", rows: windRows(c.wind)))

        sections.append(WeatherSection(title: "Visibility & Pressure", rows: [
            WeatherRow(title: "Visibility", value: c.visibility?.distanceSm.map { fmt("%.1f sm", $0) } ?? "—"),
            WeatherRow(title: "Altimeter",  value: c.pressureHg.map { fmt("%.2f inHg", $0) } ?? "—"),
            WeatherRow(title: "QNH",        value: c.pressureHpa.map { fmt("%.0f hPa", $0) } ?? "—")
        ]))

        sections.append(WeatherSection(title: "Clouds", rows: cloudRows(c.cloudLayers)))

        if let wx = c.weather, !wx.isEmpty {
            sections.append(WeatherSection(title: "Weather",
                                           rows: [WeatherRow(title: "Phenomena", value: wx.joined(separator: ", "))]))
        }

        return sections
    }

    // MARK: Forecast

    private static func forecastSections(_ f: Forecast?) -> [WeatherSection] {
        guard let f else {
            return [WeatherSection(title: "", rows: [WeatherRow(title: "No forecast available", value: "")])]
        }

        var sections: [WeatherSection] = []

        var overviewRows: [WeatherRow] = [
            WeatherRow(title: "Station", value: f.ident ?? "—"),
            WeatherRow(title: "Issued",  value: formatDate(f.dateIssued))
        ]
        if let p = f.period {
            overviewRows.append(WeatherRow(title: "Valid From", value: formatDate(p.dateStart)))
            overviewRows.append(WeatherRow(title: "Valid To",   value: formatDate(p.dateEnd)))
        }
        sections.append(WeatherSection(title: "Forecast Overview", rows: overviewRows))

        for (i, fc) in (f.conditions ?? []).enumerated() {
            var rows: [WeatherRow] = []
            if let change = fc.change?.indicator {
                rows.append(WeatherRow(title: "Change",
                                       value: [change.code, change.text].compactMap { $0 }.joined(separator: " – ")))
            }
            rows.append(WeatherRow(title: "From",         value: formatDate(fc.dateStart)))
            rows.append(WeatherRow(title: "To",           value: formatDate(fc.dateEnd)))
            rows.append(WeatherRow(title: "Flight Rules", value: fc.flightRules ?? "—"))
            rows.append(contentsOf: windRows(fc.wind))
            if let vis = fc.visibility?.distanceSm {
                rows.append(WeatherRow(title: "Visibility", value: fmt("%.1f sm", vis)))
            }
            rows.append(contentsOf: cloudRows(fc.cloudLayers))
            if let wx = fc.weather, !wx.isEmpty {
                rows.append(WeatherRow(title: "Weather", value: wx.joined(separator: ", ")))
            }
            sections.append(WeatherSection(title: "Period \(i + 1)", rows: rows))
        }

        return sections
    }

    // MARK: Shared row builders

    private static func windRows(_ wind: Wind?) -> [WeatherRow] {
        guard let w = wind else { return [WeatherRow(title: "Wind", value: "Calm")] }
        let dir = w.variable == true ? "Variable" : (w.direction.map { fmt("%.0f°", $0) } ?? "—")
        var rows = [
            WeatherRow(title: "Direction", value: dir),
            WeatherRow(title: "Speed",     value: w.speedKts.map { fmt("%.0f kts", $0) } ?? "Calm")
        ]
        if let g = w.gustSpeedKts { rows.append(WeatherRow(title: "Gusts", value: fmt("%.0f kts", g))) }
        return rows
    }

    private static func cloudRows(_ layers: [CloudLayer]?) -> [WeatherRow] {
        guard let layers, !layers.isEmpty else { return [WeatherRow(title: "Sky", value: "Clear")] }
        return layers.map { layer in
            let cov  = (layer.coverage ?? "?").uppercased()
            let alt  = layer.altitudeFt.map { fmt("%.0f ft", $0) } ?? "?"
            let ceil = layer.ceiling == true ? " ★" : ""
            return WeatherRow(title: cov + ceil, value: alt)
        }
    }

    // MARK: Formatters

    private static func fmt(_ format: String, _ value: Double) -> String {
        String(format: format, value)
    }

    private static func formatDate(_ iso: String?) -> String {
        guard let iso else { return "—" }
        let f = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ] {
            f.formatOptions = options
            if let date = f.date(from: iso) {
                let df = DateFormatter()
                df.dateStyle = .short
                df.timeStyle = .short
                return df.string(from: date)
            }
        }
        return iso
    }
}
