import Combine
import CoreAudio
import Foundation
import os

@MainActor
final class AudioCoordinator: ObservableObject {
    @Published private(set) var connected: [AudioDevice] = []
    @Published private(set) var currentDefaults: [DefaultKind: String] = [:]

    let store: PriorityStore
    private let bridge: any AudioBridge
    private let log = Logger(subsystem: "nilswesthoff.BarAudioSource", category: "Coordinator")

    private var enforcing = false
    private var cancellables = Set<AnyCancellable>()
    private var eventTask: Task<Void, Never>?

    init(bridge: any AudioBridge, store: PriorityStore) {
        self.bridge = bridge
        self.store = store
    }

    func start() {
        guard eventTask == nil else { return }

        refreshDevices()
        refreshAllDefaults()

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.enforce() }
            .store(in: &cancellables)

        let stream = bridge.events()
        eventTask = Task { @MainActor [weak self] in
            for await event in stream {
                self?.handle(event)
            }
        }

        enforce()
    }

    func stop() {
        eventTask?.cancel()
        eventTask = nil
        cancellables.removeAll()
    }

    func device(forUID uid: String) -> AudioDevice? {
        connected.first(where: { $0.uid == uid })
    }

    func availableDevices(scope: Scope) -> [AudioDevice] {
        let listed = Set(list(for: scope).entries.map(\.uid))
        return connected
            .filter { $0.scopes.contains(scope) && !listed.contains($0.uid) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func activeDeviceName(_ kind: DefaultKind) -> String? {
        guard let uid = currentDefaults[kind] else { return nil }
        return connected.first(where: { $0.uid == uid })?.name
    }

    private func handle(_ event: AudioEvent) {
        switch event {
        case .devicesChanged:
            refreshDevices()
            store.output.refreshNames(from: connected)
            store.input.refreshNames(from: connected)
            refreshAllDefaults()
            enforce()
        case .defaultChanged(let kind):
            refreshDefault(kind)
            enforce()
        }
    }

    private func refreshDevices() {
        connected = bridge.snapshot()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func refreshAllDefaults() {
        for kind in DefaultKind.allCases {
            refreshDefault(kind)
        }
    }

    private func refreshDefault(_ kind: DefaultKind) {
        guard let id = bridge.currentDefault(kind),
              let device = connected.first(where: { $0.id == id }) else {
            currentDefaults[kind] = nil
            return
        }
        currentDefaults[kind] = device.uid
    }

    func enforce() {
        guard !store.paused, !enforcing else { return }
        enforcing = true
        defer { enforcing = false }

        for kind in DefaultKind.allCases {
            let list = list(for: kind.scope)
            guard let target = Resolution.resolveTarget(list: list, connected: connected) else { continue }
            guard currentDefaults[kind] != target.uid else { continue }
            let status = bridge.setDefault(kind, deviceID: target.id)
            if status == noErr {
                currentDefaults[kind] = target.uid
                log.info("\(String(describing: kind)) -> \(target.name, privacy: .public)")
            }
        }
    }

    private func list(for scope: Scope) -> PriorityList {
        switch scope {
        case .output: return store.output
        case .input: return store.input
        }
    }
}
