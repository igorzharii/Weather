import XCTest
@testable import Weather

final class WeatherModelsTests: XCTestCase {

    // MARK: - Full report round-trip

    func test_decoding_fullReport() throws {
        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let report = try JSONDecoder().decode(WeatherReport.self, from: data)

        XCTAssertEqual(report.report.conditions?.ident, "KPWM")
        XCTAssertEqual(report.report.conditions?.flightRules, "VFR")
        XCTAssertEqual(report.report.conditions?.tempC, 15.0)
        XCTAssertEqual(report.report.conditions?.wind?.speedKts, 10.0)
        XCTAssertEqual(report.report.conditions?.wind?.direction, 270.0)
        XCTAssertEqual(report.report.conditions?.visibility?.distanceSm, 10.0)
        XCTAssertEqual(report.report.conditions?.cloudLayers?.count, 1)
        XCTAssertEqual(report.report.conditions?.cloudLayers?.first?.coverage, "bkn")
        XCTAssertEqual(report.report.conditions?.cloudLayers?.first?.ceiling, true)
    }

    func test_decoding_forecast() throws {
        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let report = try JSONDecoder().decode(WeatherReport.self, from: data)

        XCTAssertNotNil(report.report.forecast)
        XCTAssertEqual(report.report.forecast?.ident, "KPWM")
        XCTAssertEqual(report.report.forecast?.conditions?.count, 1)
        XCTAssertEqual(report.report.forecast?.conditions?.first?.flightRules, "MVFR")
    }

    func test_decoding_missingOptionalFields() throws {
        let minimal = """
        {"report":{"conditions":{"ident":"KJFK"}}}
        """
        let data = try XCTUnwrap(minimal.data(using: .utf8))
        let report = try JSONDecoder().decode(WeatherReport.self, from: data)

        XCTAssertNil(report.report.conditions?.tempC)
        XCTAssertNil(report.report.conditions?.wind)
        XCTAssertNil(report.report.forecast)
    }

    func test_encoding_roundTrip() throws {
        let data = try XCTUnwrap(sampleJSON.data(using: .utf8))
        let report = try JSONDecoder().decode(WeatherReport.self, from: data)
        let encoded = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(WeatherReport.self, from: encoded)

        XCTAssertEqual(decoded.report.conditions?.ident, report.report.conditions?.ident)
        XCTAssertEqual(decoded.report.conditions?.tempC, report.report.conditions?.tempC)
    }

    func test_decoding_variableWind() throws {
        let json = """
        {"report":{"conditions":{"wind":{"speedKts":5,"direction":0,"variable":true}}}}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let report = try JSONDecoder().decode(WeatherReport.self, from: data)
        XCTAssertEqual(report.report.conditions?.wind?.variable, true)
    }

    func test_decoding_invalidJSON_throws() {
        let bad = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(WeatherReport.self, from: bad))
    }

    // MARK: - ChangeIndicator dual-shape decoding

    func test_changeIndicator_decodesFromPlainString() throws {
        let json = """
        {"report":{"forecast":{"conditions":[{"change":"FM"}]}}}
        """
        let report = try JSONDecoder().decode(WeatherReport.self, from: json.data(using: .utf8)!)
        let change = report.report.forecast?.conditions?.first?.change
        XCTAssertEqual(change?.indicator?.code, "FM")
        XCTAssertNil(change?.probability)
    }

    func test_changeIndicator_decodesFromObject() throws {
        let json = """
        {"report":{"forecast":{"conditions":[{
            "change":{"indicator":{"code":"BECMG","text":"Becoming"},"probability":30}
        }]}}}
        """
        let report = try JSONDecoder().decode(WeatherReport.self, from: json.data(using: .utf8)!)
        let change = report.report.forecast?.conditions?.first?.change
        XCTAssertEqual(change?.indicator?.code, "BECMG")
        XCTAssertEqual(change?.indicator?.text, "Becoming")
        XCTAssertEqual(change?.probability, 30)
    }

    // MARK: - Sample fixture

    private let sampleJSON = """
    {
      "report": {
        "conditions": {
          "text": "METAR KPWM 011255Z 27010KT 10SM BKN025 15/08 A2992",
          "ident": "KPWM",
          "dateIssued": "2023-01-01T12:55:00+00:00",
          "lat": 43.6461,
          "lon": -70.3094,
          "elevationFt": 76,
          "tempC": 15.0,
          "dewpointC": 8.0,
          "pressureHg": 29.92,
          "pressureHpa": 1013.2,
          "reportedAsHpa": false,
          "densityAltitudeFt": -200,
          "relativeHumidity": 56,
          "flightRules": "VFR",
          "cloudLayers": [
            {"coverage": "bkn", "altitudeFt": 2500.0, "ceiling": true}
          ],
          "weather": [],
          "visibility": {"distanceSm": 10.0, "prevailingVisSm": 10.0},
          "wind": {"speedKts": 10.0, "direction": 270.0, "variable": false}
        },
        "forecast": {
          "text": "TAF KPWM 011130Z 0112/0218 27012KT 6SM BKN015",
          "ident": "KPWM",
          "dateIssued": "2023-01-01T11:30:00+00:00",
          "period": {
            "dateStart": "2023-01-01T12:00:00+00:00",
            "dateEnd": "2023-01-02T18:00:00+00:00"
          },
          "lat": 43.6461,
          "lon": -70.3094,
          "elevationFt": 76,
          "conditions": [
            {
              "flightRules": "MVFR",
              "dateStart": "2023-01-01T12:00:00+00:00",
              "dateEnd": "2023-01-01T18:00:00+00:00",
              "wind": {"speedKts": 12.0, "direction": 270.0, "variable": false},
              "visibility": {"distanceSm": 6.0},
              "cloudLayers": [{"coverage": "bkn", "altitudeFt": 1500.0, "ceiling": true}],
              "weather": []
            }
          ]
        }
      }
    }
    """
}
