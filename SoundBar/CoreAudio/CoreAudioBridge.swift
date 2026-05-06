import CoreAudio
import Foundation
import os

enum AudioEvent: Sendable {
    case devicesChanged
    case defaultChanged(DefaultKind)
}

protocol AudioBridge: AnyObject, Sendable {
    func snapshot() -> [AudioDevice]
    func currentDefault(_ kind: DefaultKind) -> AudioDeviceID?
    func setDefault(_ kind: DefaultKind, deviceID: AudioDeviceID) -> OSStatus
    func events() -> AsyncStream<AudioEvent>
}

nonisolated final class CoreAudioBridge: AudioBridge, @unchecked Sendable {
    private let log = Logger(subsystem: "nilswesthoff.SoundBar", category: "CoreAudio")
    private let queue = DispatchQueue(label: "SoundBar.coreaudio", qos: .userInitiated)
    private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    deinit {
        removeListeners()
    }

    func snapshot() -> [AudioDevice] {
        let ids = enumerateDeviceIDs()
        return ids.compactMap { makeDevice(from: $0) }
    }

    func currentDefault(_ kind: DefaultKind) -> AudioDeviceID? {
        var address = AudioPropertyAddresses.address(for: kind)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    func setDefault(_ kind: DefaultKind, deviceID: AudioDeviceID) -> OSStatus {
        var address = AudioPropertyAddresses.address(for: kind)
        var id = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            size,
            &id
        )
        if status != noErr {
            log.error("setDefault \(String(describing: kind)) -> \(deviceID) failed: \(status)")
        }
        return status
    }

    func events() -> AsyncStream<AudioEvent> {
        AsyncStream { continuation in
            registerListener(.devices) {
                continuation.yield(.devicesChanged)
            }
            for kind in DefaultKind.allCases {
                registerListener(.defaultDevice(kind)) {
                    continuation.yield(.defaultChanged(kind))
                }
            }
            continuation.onTermination = { [weak self] _ in
                self?.removeListeners()
            }
        }
    }

    private enum ListenerTarget {
        case devices
        case defaultDevice(DefaultKind)

        var address: AudioObjectPropertyAddress {
            switch self {
            case .devices: return AudioPropertyAddresses.devices
            case .defaultDevice(let kind): return AudioPropertyAddresses.address(for: kind)
            }
        }
    }

    private func registerListener(_ target: ListenerTarget, _ handler: @escaping @Sendable () -> Void) {
        var address = target.address
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            block
        )
        if status == noErr {
            listeners.append((AudioObjectID(kAudioObjectSystemObject), address, block))
        } else {
            log.error("AddPropertyListenerBlock failed for \(String(describing: target)): \(status)")
        }
    }

    private func removeListeners() {
        for (objectID, address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(objectID, &address, queue, block)
        }
        listeners.removeAll()
    }

    private func enumerateDeviceIDs() -> [AudioDeviceID] {
        var address = AudioPropertyAddresses.devices
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size
        ) == noErr, size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &ids
        )
        guard status == noErr else { return [] }
        return ids.filter { $0 != kAudioObjectUnknown }
    }

    private func makeDevice(from id: AudioDeviceID) -> AudioDevice? {
        let name = cfStringProperty(id, address: AudioPropertyAddresses.deviceName) ?? "Unknown"
        let uid = cfStringProperty(id, address: AudioPropertyAddresses.deviceUID) ?? "name:\(name)"

        var scopes: Set<Scope> = []
        if hasStreams(deviceID: id, scope: kAudioDevicePropertyScopeOutput) {
            scopes.insert(.output)
        }
        if hasStreams(deviceID: id, scope: kAudioDevicePropertyScopeInput) {
            scopes.insert(.input)
        }
        guard !scopes.isEmpty else { return nil }

        return AudioDevice(id: id, uid: uid, name: name, scopes: scopes)
    }

    private func cfStringProperty(_ objectID: AudioObjectID, address: AudioObjectPropertyAddress) -> String? {
        var address = address
        var size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var unmanaged: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &unmanaged) { ptr -> OSStatus in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, ptr)
        }
        guard status == noErr, let unmanaged else { return nil }
        return unmanaged.takeRetainedValue() as String
    }

    private func hasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioPropertyAddresses.streamConfiguration(scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        let bufferListPtr = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPtr.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferListPtr) == noErr else {
            return false
        }
        let bufferList = bufferListPtr.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.contains { $0.mNumberChannels > 0 }
    }
}
