import Combine
import Foundation
import ServiceManagement

@MainActor
final class PriorityStore: ObservableObject {
    @Published var output: PriorityList {
        didSet { persist(output, key: Keys.output) }
    }
    @Published var input: PriorityList {
        didSet { persist(input, key: Keys.input) }
    }
    @Published var paused: Bool {
        didSet { defaults.set(paused, forKey: Keys.paused) }
    }
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    private let defaults: UserDefaults
    private let loginItem: LoginItemController
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, loginItem: LoginItemController? = nil) {
        self.defaults = defaults
        let loginItem = loginItem ?? LoginItemController()
        self.loginItem = loginItem
        self.output = Self.load(PriorityList.self, defaults: defaults, key: Keys.output)
            ?? PriorityList.empty(scope: .output)
        self.input = Self.load(PriorityList.self, defaults: defaults, key: Keys.input)
            ?? PriorityList.empty(scope: .input)
        self.paused = defaults.bool(forKey: Keys.paused)
        self.launchAtLogin = loginItem.isEnabled
    }

    func refreshLaunchAtLogin() {
        let current = loginItem.isEnabled
        if current != launchAtLogin {
            launchAtLogin = current
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItem.setEnabled(enabled)
        } catch {
            // Revert on failure without re-triggering didSet
            let current = loginItem.isEnabled
            if current != enabled {
                Task { @MainActor in self.launchAtLogin = current }
            }
        }
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum Keys {
        static let output = "priority.output"
        static let input = "priority.input"
        static let paused = "paused"
    }
}
