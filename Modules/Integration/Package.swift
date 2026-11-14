// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Integration",
    platforms: [ .iOS(.v16), .macOS(.v14) ],
    products: [
        .library(name: "IntegrationApp", targets: ["IntegrationApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ManuelSelch/Redux", .upToNextMajor(from: "1.2.12")),
        .package(path: "../../../../../../50 Coding/52 iOS/52.01 Packages/OfflineSync")
    ],
    targets: [
        .target(
            name: "IntegrationApp",
            dependencies: [
                "IntegrationCore",
                .product(name: "Redux", package: "Redux")
            ],
            path: "Sources/App"
        ),
        
            .target(
                name: "IntegrationCore",
                dependencies: [
                    .product(name: "OfflineSync", package: "OfflineSync")
                ],
                path: "Sources/Core"
            ),
            
        
    ]
)
