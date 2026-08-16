// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GODLister",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GODLister",
            resources: [
                .copy("Resources/gamelist_xbox360.csv"),
                .copy("Resources/dlc_titles.csv")
            ]
        ),
        .testTarget(
            name: "GODListerTests",
            dependencies: ["GODLister"]
        )
    ]
)
