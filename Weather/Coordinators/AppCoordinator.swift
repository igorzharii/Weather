import UIKit

final class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let navigationController: UINavigationController

    init(window: UIWindow) {
        self.window = window
        navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true
    }

    func start() {
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        addChild(AirportListCoordinator(navigationController: navigationController))
    }
}
