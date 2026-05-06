import SwiftUI

struct ScopeSection: View {
    let scope: Scope

    @EnvironmentObject private var store: PriorityStore
    @EnvironmentObject private var coordinator: AudioCoordinator

    private var list: PriorityList {
        scope == .output ? store.output : store.input
    }

    private var activeKind: DefaultKind {
        scope == .output ? .output : .input
    }

    private var activeUID: String? {
        coordinator.currentDefaults[activeKind]
    }

    private var available: [AudioDevice] {
        coordinator.availableDevices(scope: scope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if list.entries.isEmpty {
                emptyHint
            } else {
                priorityListView
            }

            if !available.isEmpty {
                availableHeader
                ForEach(available) { device in
                    DeviceRow(
                        title: device.name,
                        subtitle: nil,
                        connected: true,
                        isActive: false,
                        trailing: .add { add(device) }
                    )
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(scope == .output ? "Output" : "Input")
                .font(.headline)
            Spacer()
            if let name = coordinator.activeDeviceName(activeKind) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var emptyHint: some View {
        Text("No priority set. Add devices below.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    private var priorityListView: some View {
        VStack(spacing: 2) {
            ForEach(Array(list.entries.enumerated()), id: \.element.id) { index, entry in
                let device = coordinator.device(forUID: entry.uid)
                let connected = device != nil
                DeviceRow(
                    title: device?.name ?? entry.lastKnownName,
                    subtitle: "\(index + 1)",
                    connected: connected,
                    isActive: connected && entry.uid == activeUID,
                    trailing: .reorderRemove(
                        canMoveUp: index > 0,
                        canMoveDown: index < list.entries.count - 1,
                        moveUp: { move(from: index, to: index - 1) },
                        moveDown: { move(from: index, to: index + 2) },
                        remove: { remove(uid: entry.uid) }
                    )
                )
            }
        }
    }

    private var availableHeader: some View {
        Text("Available")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func add(_ device: AudioDevice) {
        if scope == .output {
            store.output.add(device)
        } else {
            store.input.add(device)
        }
    }

    private func remove(uid: String) {
        if scope == .output {
            store.output.remove(uid: uid)
        } else {
            store.input.remove(uid: uid)
        }
    }

    private func move(from source: Int, to destination: Int) {
        if scope == .output {
            store.output.move(from: source, to: destination)
        } else {
            store.input.move(from: source, to: destination)
        }
    }
}
