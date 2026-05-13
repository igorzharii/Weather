import SwiftUI

// Embedded inside WeatherDetailViewController via UIHostingController.

struct WeatherContentView: View {
    let rawText: String?
    let sections: [WeatherSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let rawText {
                    RawTextCard(text: rawText)
                        .padding(.bottom, 8)
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    if !section.title.isEmpty {
                        Text(section.title.uppercased())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, section.title == sections.first?.title && rawText == nil ? 0 : 12)
                            .padding(.bottom, 4)
                    }
                    VStack(spacing: 4) {
                        ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                            WeatherRowCard(title: row.title, value: row.value)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Private subviews

private struct WeatherRowCard: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.body)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct RawTextCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
