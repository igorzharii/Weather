import UIKit
import SwiftUI

final class AirportListCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private let store: AirportStore
    private let service: WeatherServiceProtocol

    init(
        navigationController: UINavigationController,
        store: AirportStore = .shared,
        service: WeatherServiceProtocol = WeatherService.shared
    ) {
        self.navigationController = navigationController
        self.store = store
        self.service = service
    }

    func start() {
        let vm = AirportListViewModel(store: store, service: service)
        vm.onShowDetail = { [weak self] in self?.showDetail(for: $0) }
        vm.onShowSettings = { [weak self] in self?.showSettings() }
        navigationController.setViewControllers([AirportListViewController(viewModel: vm)], animated: false)
    }

    private func showDetail(for identifier: String) {
        let vm = WeatherDetailViewModel(identifier: identifier, service: service, store: store)
        navigationController.pushViewController(WeatherDetailViewController(viewModel: vm), animated: true)
    }

    private func showSettings() {
        // SwiftUI view pushed onto the UIKit navigation stack via UIHostingController
        let host = UIHostingController(rootView: SettingsView(viewModel: SettingsViewModel()))
        navigationController.pushViewController(host, animated: true)
    }
}
