import Foundation

/// A partition that can hold a file system, mounted or not.
public struct DiskVolume: Equatable, Sendable {
    public let bsdName: String
    /// The IOKit path of the hardware, shared by all its disks, APFS ones included, which DiskArbitration lists as a disk of their own.
    public let deviceID: String
    public let deviceName: String
    public let name: String
    public let maybeMountURL: URL?

    public init(bsdName: String, deviceID: String, deviceName: String, name: String, maybeMountURL: URL?) {
        self.bsdName = bsdName
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.name = name
        self.maybeMountURL = maybeMountURL
    }
}

/// A plugged-in piece of hardware and its volumes: one icon on the bar.
public struct Device: Equatable, Sendable {
    public let id: String
    public let name: String
    public let volumes: [DiskVolume]

    public init(id: String, name: String, volumes: [DiskVolume]) {
        self.id = id
        self.name = name
        self.volumes = volumes
    }
}

/// Whether a partition is on media someone plugged in: removable or ejectable, not a disk image, with a file system.
/// The media decides, not the hardware: the Mac's own SD reader reports itself as internal.
public func isPhysicalVolume(isRemovable: Bool, isEjectable: Bool, deviceProtocol: String?, isMountable: Bool) -> Bool {
    // DiskArbitration reports disk images on the "Virtual Interface" protocol.
    (isRemovable || isEjectable) && deviceProtocol != "Virtual Interface" && isMountable
}

/// One device per piece of hardware, in the order they first appear; volumes in partition order.
public func groupDevices(_ volumes: [DiskVolume]) -> [Device] {
    let ids = volumes.map(\.deviceID).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    return ids.map { id in
        let ofDevice = volumes.filter { $0.deviceID == id }
            .sorted { $0.bsdName.compare($1.bsdName, options: .numeric) == .orderedAscending }
        return Device(id: id, name: ofDevice[0].deviceName, volumes: ofDevice)
    }
}

/// The tooltip and VoiceOver label: the mounted volumes' names, or the device's name when none is mounted. "Ejecting …" while it ejects.
public func deviceLabel(_ device: Device, isEjecting: Bool = false) -> String {
    let mounted = device.volumes.filter { $0.maybeMountURL != nil }.map(\.name)
    let label = mounted.isEmpty ? device.name : mounted.joined(separator: ", ")
    return isEjecting ? "Ejecting \(label)…" : label
}

/// "SanDisk Ultra" from the vendor and model the hardware reports, which can be blank or padded; `fallback` when both are blank.
/// Also `fallback` for internal hardware: there, vendor and model name the Mac's own reader, not the card in it.
public func deviceName(vendor: String?, model: String?, isInternal: Bool = false, fallback: String) -> String {
    guard !isInternal else { return fallback }
    let name = [vendor, model].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    return name.isEmpty ? fallback : name
}
