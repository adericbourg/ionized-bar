// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "IonizedBar",
    platforms: [.macOS("27.2")],
    targets: [
        .executableTarget(name: "IonizedBar")
    ]
)
