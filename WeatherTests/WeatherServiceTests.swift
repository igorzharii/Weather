import XCTest
@testable import Weather

final class WeatherServiceTests: XCTestCase {

    private var service: WeatherService!

    override func setUp() {
        super.setUp()
        service = WeatherService(session: .mockSession())
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Success

    func test_fetchWeather_success_decodesReport() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: URL(string: "https://qa.foreflight.com")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (response, Self.validPayload)
        }

        let report = try await service.fetchWeather(for: "KPWM")
        XCTAssertEqual(report.report.conditions?.ident, "KPWM")
        XCTAssertEqual(report.report.conditions?.flightRules, "VFR")
    }

    func test_fetchWeather_setsRequiredHeader() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = try XCTUnwrap(HTTPURLResponse(
                url: request.url!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (response, Self.validPayload)
        }

        _ = try await service.fetchWeather(for: "KAUS")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "ff-coding-exercise"), "1")
    }

    func test_fetchWeather_uppercasesIdentifier() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            let response = try XCTUnwrap(HTTPURLResponse(
                url: request.url!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (response, Self.validPayload)
        }

        _ = try await service.fetchWeather(for: "kpwm")
        XCTAssertTrue(capturedURL?.absoluteString.contains("KPWM") == true)
    }

    // MARK: - Errors

    func test_fetchWeather_emptyIdentifier_throwsInvalidIdentifier() async {
        do {
            _ = try await service.fetchWeather(for: "")
            XCTFail("Expected error")
        } catch WeatherServiceError.invalidIdentifier {
            // expected
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_fetchWeather_http404_throwsHttpError() async {
        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: request.url!,
                statusCode: 404, httpVersion: nil, headerFields: nil
            ))
            return (response, Data())
        }

        do {
            _ = try await service.fetchWeather(for: "ZZZZ")
            XCTFail("Expected error")
        } catch WeatherServiceError.httpError(let code) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func test_fetchWeather_malformedJSON_throwsDecodingError() async {
        MockURLProtocol.requestHandler = { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: request.url!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            return (response, "not json".data(using: .utf8)!)
        }

        do {
            _ = try await service.fetchWeather(for: "KPWM")
            XCTFail("Expected error")
        } catch is DecodingError {
            // expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_fetchWeather_networkError_propagates() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await service.fetchWeather(for: "KPWM")
            XCTFail("Expected error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Fixture

    private static let validPayload: Data = {
        let json = """
        {"report":{"conditions":{"ident":"KPWM","flightRules":"VFR","tempC":15.0}}}
        """
        return json.data(using: .utf8)!
    }()
}
