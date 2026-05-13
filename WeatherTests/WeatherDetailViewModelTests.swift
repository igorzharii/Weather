import XCTest
import Combine
@testable import Weather

@MainActor
final class WeatherDetailViewModelTests: XCTestCase {

    private var service: MockWeatherService!
    private var store: AirportStore!
    private var cancellables = Set<AnyCancellable>()

    private var weatherCacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WeatherReports", isDirectory: true)
    }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "saved_airports")
        try? FileManager.default.removeItem(at: weatherCacheDir)
        service = MockWeatherService()
        store = AirportStore()
    }

    override func tearDown() {
        cancellables.removeAll()
        service = nil
        store = nil
        try? FileManager.default.removeItem(at: weatherCacheDir)
        UserDefaults.standard.removeObject(forKey: "saved_airports")
        super.tearDown()
    }

    // MARK: - Initial state

    func test_init_withCachedReport_startsAsLoaded() {
        store.cache(makeReport(), for: "KPWM")
        let vm = makeVM()
        guard case .loaded = vm.displayContent else {
            return XCTFail("Expected .loaded, got \(vm.displayContent)")
        }
    }

    func test_init_withoutCache_startsAsLoading() {
        let vm = makeVM()
        guard case .loading = vm.displayContent else {
            return XCTFail("Expected .loading, got \(vm.displayContent)")
        }
    }

    func test_identifier_isExposed() {
        let vm = makeVM(identifier: "KAUS")
        XCTAssertEqual(vm.identifier, "KAUS")
    }

    // MARK: - Fetch success

    func test_fetch_success_transitionsToLoaded() async {
        service.result = .success(makeReport())
        let vm = makeVM()
        let exp = expectation(description: "loaded")
        vm.$displayContent
            .first { if case .loaded = $0 { return true }; return false }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        vm.fetch()
        await fulfillment(of: [exp], timeout: 2)
    }

    func test_fetch_success_cachesReportInStore() async throws {
        service.result = .success(makeReport(ident: "KPWM"))
        let vm = makeVM()
        vm.fetch()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNotNil(store.cachedReport(for: "KPWM"))
    }

    // MARK: - Fetch failure

    func test_fetch_failure_withoutCache_transitionsToError() async {
        service.result = .failure(URLError(.notConnectedToInternet))
        let vm = makeVM()
        let exp = expectation(description: "error")
        vm.$displayContent
            .first { if case .error = $0 { return true }; return false }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        vm.fetch()
        await fulfillment(of: [exp], timeout: 2)
    }

    func test_fetch_failure_withExistingCache_keepsLoadedState() async throws {
        store.cache(makeReport(), for: "KPWM")
        service.result = .failure(URLError(.notConnectedToInternet))
        let vm = makeVM()
        vm.fetch()
        try await Task.sleep(for: .milliseconds(200))
        guard case .loaded = vm.displayContent else {
            return XCTFail("Should remain .loaded when cache is present")
        }
    }

    // MARK: - Mode switching

    func test_modeSwitch_toForecast_rebuildsContent() {
        store.cache(makeReport(withForecast: true), for: "KPWM")
        let vm = makeVM()
        let exp = expectation(description: "forecast content")
        vm.$displayContent
            .dropFirst()
            .first { if case .loaded(_, let s) = $0 { return s.contains { $0.title == "Forecast Overview" } }; return false }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        vm.mode = .forecast
        wait(for: [exp], timeout: 1)
    }

    func test_modeSwitch_backToConditions_rebuildsContent() {
        store.cache(makeReport(withForecast: true), for: "KPWM")
        let vm = makeVM()
        vm.mode = .forecast
        let exp = expectation(description: "conditions content")
        vm.$displayContent
            .dropFirst()
            .first { if case .loaded(_, let s) = $0 { return s.contains { $0.title == "Overview" } }; return false }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        vm.mode = .conditions
        wait(for: [exp], timeout: 1)
    }

    // MARK: - Display content structure

    func test_conditions_containsExpectedSectionTitles() {
        store.cache(makeReport(flightRules: "VFR", tempC: 10), for: "KPWM")
        let vm = makeVM()
        guard case .loaded(_, let sections) = vm.displayContent else { return XCTFail() }
        let titles = Set(sections.map(\.title))
        XCTAssertTrue(titles.contains("Overview"))
        XCTAssertTrue(titles.contains("Temperature"))
        XCTAssertTrue(titles.contains("Wind"))
        XCTAssertTrue(titles.contains("Visibility & Pressure"))
        XCTAssertTrue(titles.contains("Clouds"))
    }

    func test_conditions_flightRulesRowValue() {
        store.cache(makeReport(flightRules: "IFR"), for: "KPWM")
        let vm = makeVM()
        guard case .loaded(_, let sections) = vm.displayContent else { return XCTFail() }
        let rulesValue = sections.first { $0.title == "Overview" }?
            .rows.first { $0.title == "Flight Rules" }?.value
        XCTAssertEqual(rulesValue, "IFR")
    }

    func test_conditions_tempFormatIncludesCelsiusAndFahrenheit() {
        store.cache(makeReport(tempC: 0), for: "KPWM")
        let vm = makeVM()
        guard case .loaded(_, let sections) = vm.displayContent else { return XCTFail() }
        let tempValue = sections.first { $0.title == "Temperature" }?
            .rows.first { $0.title == "Temp" }?.value
        XCTAssertTrue(tempValue?.contains("°C") == true)
        XCTAssertTrue(tempValue?.contains("°F") == true)
    }

    func test_conditions_rawTextIsExposed() {
        store.cache(makeReport(rawText: "METAR KPWM ..."), for: "KPWM")
        let vm = makeVM()
        guard case .loaded(let rawText, _) = vm.displayContent else { return XCTFail() }
        XCTAssertEqual(rawText, "METAR KPWM ...")
    }

    func test_noConditions_showsPlaceholderSection() {
        let empty = WeatherReport(report: Report(conditions: nil, forecast: nil))
        store.cache(empty, for: "KPWM")
        let vm = makeVM()
        guard case .loaded(_, let sections) = vm.displayContent else { return XCTFail() }
        XCTAssertFalse(sections.isEmpty)
    }

    // MARK: - Helpers

    private func makeVM(identifier: String = "KPWM") -> WeatherDetailViewModel {
        WeatherDetailViewModel(identifier: identifier, service: service, store: store)
    }

    private func makeReport(
        ident: String = "KPWM",
        rawText: String? = nil,
        flightRules: String? = "VFR",
        tempC: Double? = 15,
        withForecast: Bool = false
    ) -> WeatherReport {
        WeatherReport(report: Report(
            conditions: Conditions(
                text: rawText, ident: ident, dateIssued: nil,
                lat: nil, lon: nil, elevationFt: nil,
                tempC: tempC, dewpointC: nil,
                pressureHg: nil, pressureHpa: nil, reportedAsHpa: nil,
                densityAltitudeFt: nil, relativeHumidity: nil,
                flightRules: flightRules, cloudLayers: nil, cloudLayersV2: nil,
                weather: nil, visibility: nil, wind: nil
            ),
            forecast: withForecast ? Forecast(
                text: "TAF KPWM ...", ident: ident, dateIssued: nil,
                period: Period(dateStart: nil, dateEnd: nil),
                lat: nil, lon: nil, elevationFt: nil, conditions: []
            ) : nil
        ))
    }
}
