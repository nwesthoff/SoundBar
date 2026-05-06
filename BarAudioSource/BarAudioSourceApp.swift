import SwiftUI

@main
struct BarAudioSourceApp: App {
    @StateObject private var store: PriorityStore
    @StateObject private var coordinator: AudioCoordinator

    init() {
        let store = PriorityStore()
        let bridge = CoreAudioBridge()
        let coordinator = AudioCoordinator(bridge: bridge, store: store)
        _store = StateObject(wrappedValue: store)
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRoot()
                .environmentObject(store)
                .environmentObject(coordinator)
                .task { coordinator.start() }
        } label: {
            Image(systemName: "speaker.wave.2.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
