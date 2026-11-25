import AppKit
import DiskArbitration
import IonizedBarCore

/// The storage plugged in, from DiskArbitration: unlike NSWorkspace it tells which hardware each volume is on.
@MainActor
final class DeviceMonitor {
    var onChange: (() -> Void)?
    private(set) var devices: [Device] = []
    /// Ids of the devices an eject is running on: it can take seconds.
    private(set) var ejecting: Set<String> = []
    private let session = DASessionCreate(kCFAllocatorDefault)!
    // In order of appearance, so the icons keep their place.
    private var disks: [DADisk] = []

    init() {
        // Unretained: the monitor lives as long as the app.
        let context = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskAppearedCallback(session, nil, { disk, context in
            MainActor.assumeIsolated { DeviceMonitor.from(context).appeared(disk) }
        }, context)
        DARegisterDiskDisappearedCallback(session, nil, { disk, context in
            MainActor.assumeIsolated { DeviceMonitor.from(context).disappeared(disk) }
        }, context)
        // Mounting and unmounting change the volume path.
        DARegisterDiskDescriptionChangedCallback(session, nil, [kDADiskDescriptionVolumePathKey] as CFArray, { _, _, context in
            MainActor.assumeIsolated { DeviceMonitor.from(context).refresh() }
        }, context)
        DASessionSetDispatchQueue(session, .main)
    }

    private nonisolated static func from(_ context: UnsafeMutableRawPointer?) -> DeviceMonitor {
        Unmanaged.fromOpaque(context!).takeUnretainedValue()
    }

    private func appeared(_ disk: DADisk) {
        disks.append(disk)
        refresh()
    }

    private func disappeared(_ disk: DADisk) {
        disks.removeAll { $0 == disk }
        refresh()
    }

    private func refresh() {
        let newDevices = groupDevices(disks.compactMap(Self.volume))
        // An ejected disk may no longer describe itself to `finishEjecting`: don't leave a replugged device dimmed.
        ejecting.formIntersection(newDevices.map(\.id))
        guard newDevices != devices else { return }
        devices = newDevices
        onChange?()
    }

    private static func volume(of disk: DADisk) -> DiskVolume? {
        guard let description = DADiskCopyDescription(disk) as NSDictionary?,
              let bsdName = description[kDADiskDescriptionMediaBSDNameKey] as? String,
              let deviceID = description[kDADiskDescriptionDevicePathKey] as? String,
              isPhysicalVolume(
                  isRemovable: description[kDADiskDescriptionMediaRemovableKey] as? Bool ?? false,
                  isEjectable: description[kDADiskDescriptionMediaEjectableKey] as? Bool ?? false,
                  deviceProtocol: description[kDADiskDescriptionDeviceProtocolKey] as? String,
                  isMountable: description[kDADiskDescriptionVolumeMountableKey] as? Bool ?? false
              )
        else { return nil }
        let name = description[kDADiskDescriptionVolumeNameKey] as? String ?? bsdName
        return DiskVolume(
            bsdName: bsdName, deviceID: deviceID,
            deviceName: deviceName(
                vendor: description[kDADiskDescriptionDeviceVendorKey] as? String,
                model: description[kDADiskDescriptionDeviceModelKey] as? String,
                isInternal: description[kDADiskDescriptionDeviceInternalKey] as? Bool ?? false, fallback: name
            ),
            name: name, maybeMountURL: description[kDADiskDescriptionVolumePathKey] as? URL
        )
    }

    func mount(_ volume: DiskVolume) {
        guard let disk = disk(volume) else { return }
        DADiskMount(disk, nil, DADiskMountOptions(kDADiskMountOptionDefault), { disk, dissenter, _ in
            MainActor.assumeIsolated { DeviceMonitor.report(dissenter, disk, failedTo: "mounted") }
        }, nil)
    }

    private func disk(_ volume: DiskVolume) -> DADisk? {
        disks.first { DADiskGetBSDName($0).map { String(cString: $0) } == volume.bsdName }
    }

    /// Unmounts `volume` only. The last mounted volume takes the hardware with it, so it can be pulled out.
    func eject(_ volume: DiskVolume, of device: Device) {
        guard device.volumes.filter({ $0.maybeMountURL != nil }) != [volume] else { return ejectAll(device) }
        guard let disk = disk(volume) else { return }
        startEjecting(device)
        DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionDefault), { disk, dissenter, context in
            MainActor.assumeIsolated { DeviceMonitor.from(context).finishEjecting(disk, dissenter) }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    /// Unmounts every volume of the hardware, its APFS disks included, then ejects it.
    func ejectAll(_ device: Device) {
        guard let root = physicalDisk(of: device) else { return }
        startEjecting(device)
        DADiskUnmount(root, DADiskUnmountOptions(kDADiskUnmountOptionWhole), { disk, dissenter, context in
            MainActor.assumeIsolated {
                guard dissenter == nil else { return DeviceMonitor.from(context).finishEjecting(disk, dissenter) }
                DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), { disk, dissenter, context in
                    MainActor.assumeIsolated { DeviceMonitor.from(context).finishEjecting(disk, dissenter) }
                }, context)
            }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func startEjecting(_ device: Device) {
        ejecting.insert(device.id)
        onChange?()
    }

    /// On failure too, so the device can be ejected again.
    private func finishEjecting(_ disk: DADisk, _ maybeDissenter: DADissenter?) {
        if let deviceID = (DADiskCopyDescription(disk) as NSDictionary?)?[kDADiskDescriptionDevicePathKey] as? String {
            ejecting.remove(deviceID)
            onChange?()
        }
        Self.report(maybeDissenter, disk, failedTo: "ejected")
    }

    /// The whole disk at the root of the hardware's IOKit tree: its APFS disks sit deeper, under one of its partitions.
    private func physicalDisk(of device: Device) -> DADisk? {
        disks.compactMap { disk -> (disk: DADisk, mediaPath: String)? in
            guard let description = DADiskCopyDescription(disk) as NSDictionary?,
                  description[kDADiskDescriptionDevicePathKey] as? String == device.id,
                  description[kDADiskDescriptionMediaWholeKey] as? Bool == true,
                  let mediaPath = description[kDADiskDescriptionMediaPathKey] as? String
            else { return nil }
            return (disk, mediaPath)
        }.min { $0.mediaPath.count < $1.mediaPath.count }?.disk
    }

    private static func report(_ maybeDissenter: DADissenter?, _ disk: DADisk, failedTo verb: String) {
        guard let dissenter = maybeDissenter else { return }
        let description = DADiskCopyDescription(disk) as NSDictionary?
        let name = description?[kDADiskDescriptionVolumeNameKey] as? String ?? description?[kDADiskDescriptionMediaNameKey] as? String ?? "The disk"
        let status = DADissenterGetStatus(dissenter)
        let alert = NSAlert()
        alert.messageText = "“\(name)” couldn’t be \(verb)"
        alert.informativeText = DADissenterGetStatusString(dissenter) as String?
            ?? (status == kDAReturnBusy ? "An app is using it. Close its files there, then try again." : "DiskArbitration error \(String(format: "0x%x", status)).")
        // The app is never active on its own, and an inactive app's alert opens behind the other windows.
        NSApp.activate()
        alert.runModal()
    }
}
