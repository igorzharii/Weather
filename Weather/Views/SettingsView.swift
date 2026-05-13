import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section {
                ForEach(viewModel.intervals, id: \.self) { interval in
                    HStack {
                        Text(interval.title)
                        Spacer()
                        if viewModel.selectedInterval == interval {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.select(interval) }
                }
            } header: {
                Text("Auto-Refresh Interval")
            } footer: {
                Text("Automatically fetches updated weather for all airports at the selected interval.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
