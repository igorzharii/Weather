import XCTest
import Combine
@testable import Weather

@MainActor
final class AirportListViewModelTests: XCTestCase {

    private var store: AirportStore!
    private var service: MockWeatherService!
    private var viewModel: AirportListViewModel!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "saved_airports")
        store = AirportStore()
        service = MockWeatherService()
        viewModel = AirportListViewModel(store: store, service: service)
    }

    override func tearDown() {
        cancellables.removeAll()
        viewModel = nil
        service = nil
        store = nil
        UserDefaults.standard.removeObject(forKey: "saved_airports")
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialAirports_matchesStore() {
        XCTAssertEqual(viewModel.airports, store.airports)
    }

    // MARK: - Add

    func test_add_appendsAirportAndPublishes() {
        let exp = expectation(description: "airports published")
        viewModel.$airports
            .dropFirst()
            .first()
            .sink { airports in
                XCTAssertTrue(airports.contains("KJFK"))
                exp.fulfill()
            }
            .store(in: &cancellables)

        viewModel.add(identifier: "kjfk")
        wait(for: [exp], timeout: 1)
    }

    func test_add_uppercasesAndTrimsWhitespace() {
        viewModel.add(identifier: " kjfk ")
        XCTAssertTrue(viewModel.airports.contains("KJFK"))
    }

    func test_add_emptyOrWhitespace_isNoOp() {
        let before = viewModel.airports.count
        viewModel.add(identifier: "   ")
        XCTAssertEqual(viewModel.airports.count, before)
    }

    func test_add_triggersShowDetailWithUppercasedId() {
        var received: String?
        viewModel.onShowDetail = { received = $0 }
        viewModel.add(identifier: "ksea")
        XCTAssertEqual(received, "KSEA")
    }

    func test_add_duplicate_doesNotDuplicate() {
        viewModel.add(identifier: "KPWM")
        let count = viewModel.airports.filter { $0 == "KPWM" }.count
        XCTAssertEqual(count, 1)
    }

    // MARK: - Remove

    func test_remove_deletesAirport() {
        viewModel.add(identifier: "KJFK")
        let idx = viewModel.airports.firstIndex(of: "KJFK")!
        viewModel.remove(at: idx)
        XCTAssertFalse(viewModel.airports.contains("KJFK"))
    }

    func test_remove_outOfBounds_doesNotCrash() {
        viewModel.remove(at: 999)
    }

    // MARK: - Select

    func test_select_triggersShowDetail() {
        guard !viewModel.airports.isEmpty else { return }
        var received: String?
        viewModel.onShowDetail = { received = $0 }
        viewModel.select(at: 0)
        XCTAssertEqual(received, viewModel.airports[0])
    }

    func test_select_outOfBounds_doesNotCrash() {
        viewModel.select(at: 999)
    }

    // MARK: - Refresh

    func test_refresh_reloadsAirportsFromStore() {
        // Simulate an airport added directly to the store (e.g. by another codepath)
        // without going through the ViewModel, then verify refresh picks it up.
        store.add(airport: "KSFO")
        XCTAssertFalse(viewModel.airports.contains("KSFO"))
        viewModel.refresh()
        XCTAssertTrue(viewModel.airports.contains("KSFO"))
    }

    // MARK: - Settings

    func test_requestSettings_firesCallback() {
        var called = false
        viewModel.onShowSettings = { called = true }
        viewModel.requestSettings()
        XCTAssertTrue(called)
    }

    // MARK: - Subtitle

    func test_subtitle_withCachedVFR_returnsColourAndText() {
        store.cache(makeReport(ident: "KPWM", flightRules: "VFR", tempC: 15), for: "KPWM")
        let sub = viewModel.subtitle(for: "KPWM")
        XCTAssertNotNil(sub)
        XCTAssertTrue(sub?.text.contains("VFR") == true)
        XCTAssertTrue(sub?.text.contains("15°C") == true)
        XCTAssertEqual(sub?.color, .systemGreen)
    }

    func test_subtitle_withoutCache_returnsNil() {
        XCTAssertNil(viewModel.subtitle(for: "ZZZZ"))
    }

    // MARK: - Helpers

    private func makeReport(ident: String, flightRules: String? = nil, tempC: Double? = nil) -> WeatherReport {
        WeatherReport(report: Report(
            conditions: Conditions(
                text: nil, ident: ident, dateIssued: nil,
                lat: nil, lon: nil, elevationFt: nil,
                tempC: tempC, dewpointC: nil,
                pressureHg: nil, pressureHpa: nil, reportedAsHpa: nil,
                densityAltitudeFt: nil, relativeHumidity: nil,
                flightRules: flightRules, cloudLayers: nil, cloudLayersV2: nil,
                weather: nil, visibility: nil, wind: nil
            ),
            forecast: nil
        ))
    }
}
