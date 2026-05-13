import XCTest
@testable import Weather

@MainActor
final class AirportStoreTests: XCTestCase {

    private var store: AirportStore!
    private let testKey = "saved_airports"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: testKey)
        store = AirportStore()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        store = nil
        super.tearDown()
    }

    // MARK: - Default airports

    func test_defaultAirports_containsKPWMandKAUS() {
        XCTAssertTrue(store.airports.contains("KPWM"))
        XCTAssertTrue(store.airports.contains("KAUS"))
    }

    // MARK: - Add

    func test_add_appendsUppercased() {
        store.airports = []
        store.add(airport: "kjfk")
        XCTAssertTrue(store.airports.contains("KJFK"))
    }

    func test_add_doesNotDuplicate() {
        store.airports = ["KJFK"]
        store.add(airport: "kjfk")
        XCTAssertEqual(store.airports.filter { $0 == "KJFK" }.count, 1)
    }

    func test_add_preservesOrder() {
        store.airports = ["KPWM"]
        store.add(airport: "KAUS")
        store.add(airport: "KJFK")
        XCTAssertEqual(store.airports, ["KPWM", "KAUS", "KJFK"])
    }

    // MARK: - Remove

    func test_remove_deletesAirport() {
        store.airports = ["KPWM", "KAUS"]
        store.remove(airport: "KPWM")
        XCTAssertFalse(store.airports.contains("KPWM"))
        XCTAssertTrue(store.airports.contains("KAUS"))
    }

    func test_remove_caseInsensitive() {
        store.airports = ["KPWM"]
        store.remove(airport: "kpwm")
        XCTAssertFalse(store.airports.contains("KPWM"))
    }

    func test_remove_nonExistentIdentifier_noOp() {
        store.airports = ["KPWM"]
        store.remove(airport: "ZZZZ")
        XCTAssertEqual(store.airports, ["KPWM"])
    }

    // MARK: - Persistence

    func test_airports_persistsToUserDefaults() {
        store.airports = ["KSFO"]
        let raw = UserDefaults.standard.stringArray(forKey: testKey)
        XCTAssertEqual(raw, ["KSFO"])
    }

    // MARK: - Cache

    func test_cache_andRetrieve_roundTrip() throws {
        let report = makeReport(ident: "KPWM")
        store.cache(report, for: "KPWM")
        let retrieved = store.cachedReport(for: "KPWM")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.report.conditions?.ident, "KPWM")
    }

    func test_cache_caseInsensitive() {
        let report = makeReport(ident: "KPWM")
        store.cache(report, for: "kpwm")
        XCTAssertNotNil(store.cachedReport(for: "KPWM"))
    }

    func test_cachedReport_returnsNilForUnknown() {
        XCTAssertNil(store.cachedReport(for: "ZZZZ"))
    }

    func test_cache_overwritesPreviousEntry() {
        store.cache(makeReport(ident: "KPWM", temp: 10), for: "KPWM")
        store.cache(makeReport(ident: "KPWM", temp: 20), for: "KPWM")
        let retrieved = store.cachedReport(for: "KPWM")
        XCTAssertEqual(retrieved?.report.conditions?.tempC, 20)
    }

    // MARK: - Helpers

    private func makeReport(ident: String, temp: Double = 15) -> WeatherReport {
        WeatherReport(report: Report(
            conditions: Conditions(
                text: nil, ident: ident, dateIssued: nil,
                lat: nil, lon: nil, elevationFt: nil,
                tempC: temp, dewpointC: nil,
                pressureHg: nil, pressureHpa: nil, reportedAsHpa: nil,
                densityAltitudeFt: nil, relativeHumidity: nil,
                flightRules: "VFR", cloudLayers: nil, cloudLayersV2: nil,
                weather: nil, visibility: nil, wind: nil
            ),
            forecast: nil
        ))
    }
}
