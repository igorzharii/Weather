import Foundation
@testable import Weather

final class MockWeatherService: WeatherServiceProtocol, @unchecked Sendable {
    var result: Result<WeatherReport, Error> = .failure(URLError(.unknown))

    func fetchWeather(for identifier: String) async throws -> WeatherReport {
        try result.get()
    }
}
