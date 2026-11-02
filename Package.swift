// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "IonizedBar",
    platforms: [.macOS("27.2")],
    targets: [
        .target(name: "IonizedBarCore"),
        .executableTarget(name: "IonizedBar", dependencies: ["IonizedBarCore"]),
        .executableTarget(name: "IonizedBarChecks", dependencies: ["IonizedBarCore"])
    ]
)
