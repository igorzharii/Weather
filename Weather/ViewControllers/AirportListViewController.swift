import UIKit
import Combine

final class AirportListViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: AirportListViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private let addField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Airport identifier (e.g. KJFK)"
        tf.autocapitalizationType = .allCharacters
        tf.autocorrectionType = .no
        tf.clearButtonMode = .whileEditing
        tf.returnKeyType = .go
        return tf
    }()

    // MARK: - Init

    init(viewModel: AirportListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refresh()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Weather"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        setupTableHeader()
        setupTableView()
        bind()
    }

    // MARK: - Setup

    private func setupTableHeader() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 56))
        addField.delegate = self
        addField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addField)
        NSLayoutConstraint.activate([
            addField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            addField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            addField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.heightAnchor.constraint(equalToConstant: 0.5),
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        tableView.tableHeaderView = container
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AirportCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Binding

    private func bind() {
        viewModel.$airports
            .sink { [weak self] _ in self?.tableView.reloadData() }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func settingsTapped() {
        viewModel.requestSettings()
    }
}

// MARK: - UITableViewDataSource

extension AirportListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.airports.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AirportCell", for: indexPath)
        let id = viewModel.airports[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = id
        if let sub = viewModel.subtitle(for: id) {
            config.secondaryText = sub.text
            config.secondaryTextProperties.color = sub.color
        }
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Saved Airports"
    }

    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard editingStyle == .delete else { return }
        viewModel.remove(at: indexPath.row)
    }
}

// MARK: - UITableViewDelegate

extension AirportListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.select(at: indexPath.row)
    }
}

// MARK: - UITextFieldDelegate

extension AirportListViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        viewModel.add(identifier: textField.text ?? "")
        textField.text = nil
        return true
    }
}
