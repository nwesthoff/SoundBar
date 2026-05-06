import CoreAudio
import Foundation

enum Scope: String, Codable, Sendable, CaseIterable {
    case input
    case output
}

enum DefaultKind: String, Sendable, CaseIterable {
    case output
    case systemOutput
    case input

    var scope: Scope {
        switch self {
        case .output, .systemOutput: return .output
        case .input: return .input
        }
    }
}

struct AudioDevice: Identifiable, Hashable, Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let scopes: Set<Scope>
}

struct PriorityEntry: Codable, Identifiable, Hashable, Sendable {
    var uid: String
    var lastKnownName: String

    var id: String { uid }
}

struct PriorityList: Codable, Sendable {
    var scope: Scope
    var entries: [PriorityEntry]

    static func empty(scope: Scope) -> PriorityList {
        PriorityList(scope: scope, entries: [])
    }

    mutating func add(_ device: AudioDevice) {
        guard !entries.contains(where: { $0.uid == device.uid }) else { return }
        entries.append(PriorityEntry(uid: device.uid, lastKnownName: device.name))
    }

    mutating func remove(uid: String) {
        entries.removeAll { $0.uid == uid }
    }

    mutating func move(from source: Int, to destination: Int) {
        guard source >= 0, source < entries.count else { return }
        guard destination >= 0, destination <= entries.count, destination != source, destination != source + 1 else { return }
        let item = entries.remove(at: source)
        let adjusted = destination > source ? destination - 1 : destination
        entries.insert(item, at: adjusted)
    }

    mutating func refreshNames(from devices: [AudioDevice]) {
        let nameByUID = Dictionary(uniqueKeysWithValues: devices.map { ($0.uid, $0.name) })
        for index in entries.indices {
            if let name = nameByUID[entries[index].uid] {
                entries[index].lastKnownName = name
            }
        }
    }
}
