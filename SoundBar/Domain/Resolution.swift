import Foundation

enum Resolution {
    static func resolveTarget(list: PriorityList, connected: [AudioDevice]) -> AudioDevice? {
        let scoped = connected.filter { $0.scopes.contains(list.scope) }
        guard !scoped.isEmpty else { return nil }
        let byUID = Dictionary(uniqueKeysWithValues: scoped.map { ($0.uid, $0) })
        for entry in list.entries {
            if let device = byUID[entry.uid] {
                return device
            }
            if entry.uid.hasPrefix("name:") {
                let target = String(entry.uid.dropFirst("name:".count))
                if let device = scoped.first(where: { $0.name == target }) {
                    return device
                }
            }
        }
        return nil
    }
}
