import Foundation

protocol WeatherServiceProtocol: Sendable {
    func fetchWeather(for identifier: String) async throws -> WeatherReport
}

enum WeatherServiceError: LocalizedError {
    case invalidIdentifier
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier: return "Invalid airport identifier."
        case .invalidResponse: return "Invalid server response."
        case .httpError(let code): return "Server error: HTTP \(code)."
        }
    }
}

final class WeatherService: WeatherServiceProtocol, Sendable {
    static let shared = WeatherService()

    private let session: URLSession
    private let baseURL = "https://qa.foreflight.com/weather/report/"

    init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func fetchWeather(for identifier: String) async throws -> WeatherReport {
        let clean = identifier.trimmingCharacters(in: .whitespaces).uppercased()
        guard !clean.isEmpty, let url = URL(string: baseURL + clean) else {
            throw WeatherServiceError.invalidIdentifier
        }

        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "ff-coding-exercise")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WeatherServiceError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(WeatherReport.self, from: data)
        } catch {
            throw error
        }
    }
}
