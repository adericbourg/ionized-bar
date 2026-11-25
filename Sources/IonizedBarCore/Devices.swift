import Foundation

/// A partition that can hold a file system, mounted or not.
public struct DiskVolume: Equatable, Sendable {
    public let bsdName: String
    public let wholeDiskBSDName: String
    public let deviceName: String
    public let name: String
    public let maybeMountURL: URL?

    public init(bsdName: String, wholeDiskBSDName: String, deviceName: String, name: String, maybeMountURL: URL?) {
        self.bsdName = bsdName
        self.wholeDiskBSDName = wholeDiskBSDName
        self.deviceName = deviceName
        self.name = name
        self.maybeMountURL = maybeMountURL
    }
}

/// A plugged-in disk and its volumes: one icon on the bar.
public struct Device: Equatable, Sendable {
    public let wholeDiskBSDName: String
    public let name: String
    public let volumes: [DiskVolume]

    public init(wholeDiskBSDName: String, name: String, volumes: [DiskVolume]) {
        self.wholeDiskBSDName = wholeDiskBSDName
        self.name = name
        self.volumes = volumes
    }
}

/// Whether a partition belongs to storage someone plugged in: not internal, removable or ejectable, not a disk image, with a file system.
public func isPhysicalVolume(isInternal: Bool, isRemovable: Bool, isEjectable: Bool, deviceProtocol: String?, isMountable: Bool) -> Bool {
    // DiskArbitration reports disk images on the "Virtual Interface" protocol.
    !isInternal && (isRemovable || isEjectable) && deviceProtocol != "Virtual Interface" && isMountable
}

/// One device per whole disk, in the order the disks first appear; volumes in partition order.
public func groupDevices(_ volumes: [DiskVolume]) -> [Device] {
    let disks = volumes.map(\.wholeDiskBSDName).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    return disks.map { disk in
        let ofDisk = volumes.filter { $0.wholeDiskBSDName == disk }
            .sorted { $0.bsdName.compare($1.bsdName, options: .numeric) == .orderedAscending }
        return Device(wholeDiskBSDName: disk, name: ofDisk[0].deviceName, volumes: ofDisk)
    }
}

/// The tooltip and VoiceOver label: the mounted volumes' names, or the device's name when none is mounted.
public func deviceLabel(_ device: Device) -> String {
    let mounted = device.volumes.filter { $0.maybeMountURL != nil }.map(\.name)
    return mounted.isEmpty ? device.name : mounted.joined(separator: ", ")
}
