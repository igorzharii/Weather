import UIKit
import Combine
import SwiftUI

final class WeatherDetailViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: WeatherDetailViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI  (UIKit chrome)

    private let segment: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Conditions", "Forecast"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let spinner: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.translatesAutoresizingMaskIntoConstraints = false
        a.hidesWhenStopped = true
        return a
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.font = .preferredFont(forTextStyle: .body)
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // SwiftUI content host (conditions / forecast cards)
    private var contentHost: UIHostingController<WeatherContentView>?

    // MARK: - Init

    init(viewModel: WeatherDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.identifier
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshTapped)
        )
        setupLayout()
        bind()
        viewModel.fetch()
    }

    // MARK: - Layout

    private func setupLayout() {
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segment)
        view.addSubview(spinner)
        view.addSubview(errorLabel)

        // Embed SwiftUI scroll content as a child view controller
        let host = UIHostingController(rootView: WeatherContentView(rawText: nil, sections: []))
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        host.view.isHidden = true
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        contentHost = host

        NSLayoutConstraint.activate([
            segment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            host.view.topAnchor.constraint(equalTo: segment.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    // MARK: - Binding

    private func bind() {
        viewModel.$displayContent
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancellables)
    }

    // MARK: - Rendering

    private func render(_ content: WeatherDisplayContent) {
        spinner.stopAnimating()
        errorLabel.isHidden = true
        contentHost?.view.isHidden = true

        switch content {
        case .loading:
            spinner.startAnimating()

        case .error(let message):
            errorLabel.text = message
            errorLabel.isHidden = false

        case .loaded(let rawText, let sections):
            contentHost?.rootView = WeatherContentView(rawText: rawText, sections: sections)
            contentHost?.view.isHidden = false
        }
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        viewModel.mode = WeatherDisplayMode(rawValue: segment.selectedSegmentIndex) ?? .conditions
    }

    @objc private func refreshTapped() {
        viewModel.fetch()
    }
}
