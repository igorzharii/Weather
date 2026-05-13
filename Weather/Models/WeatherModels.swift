import Foundation

struct WeatherReport: Codable, Sendable {
    let report: Report
}

struct Report: Codable, Sendable {
    let conditions: Conditions?
    let forecast: Forecast?
}

struct Conditions: Codable, Sendable {
    let text: String?
    let ident: String?
    let dateIssued: String?
    let lat: Double?
    let lon: Double?
    let elevationFt: Double?
    let tempC: Double?
    let dewpointC: Double?
    let pressureHg: Double?
    let pressureHpa: Double?
    let reportedAsHpa: Bool?
    let densityAltitudeFt: Double?
    let relativeHumidity: Double?
    let flightRules: String?
    let cloudLayers: [CloudLayer]?
    let cloudLayersV2: [CloudLayer]?
    let weather: [String]?
    let visibility: Visibility?
    let wind: Wind?
}

struct Forecast: Codable, Sendable {
    let text: String?
    let ident: String?
    let dateIssued: String?
    let period: Period?
    let lat: Double?
    let lon: Double?
    let elevationFt: Double?
    let conditions: [ForecastCondition]?
}

struct CloudLayer: Codable, Sendable {
    let coverage: String?
    let altitudeFt: Double?
    let ceiling: Bool?
}

struct Visibility: Codable, Sendable {
    let distanceSm: Double?
    let prevailingVisSm: Double?
}

struct Wind: Codable, Sendable {
    let speedKts: Double?
    let gustSpeedKts: Double?
    let direction: Double?
    let variable: Bool?
}

struct Period: Codable, Sendable {
    let dateStart: String?
    let dateEnd: String?
}

struct ForecastCondition: Codable, Sendable {
    let text: String?
    let dateStart: String?
    let dateEnd: String?
    let flightRules: String?
    let wind: Wind?
    let visibility: Visibility?
    let cloudLayers: [CloudLayer]?
    let weather: [String]?
    let change: ChangeIndicator?
}

struct ChangeIndicator: Codable, Sendable {
    let indicator: ChangeType?
    let probability: Double?

    // The API returns `change` as either a plain String ("FM", "BECMG")
    // or a keyed object { indicator: { code, text }, probability }.
    init(from decoder: Decoder) throws {
        if let code = try? decoder.singleValueContainer().decode(String.self) {
            indicator = ChangeType(code: code, text: nil)
            probability = nil
        } else {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            indicator = try c.decodeIfPresent(ChangeType.self, forKey: .indicator)
            probability = try c.decodeIfPresent(Double.self, forKey: .probability)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case indicator, probability
    }
}

struct ChangeType: Codable, Sendable {
    let code: String?
    let text: String?

    init(code: String?, text: String?) {
        self.code = code
        self.text = text
    }
}
