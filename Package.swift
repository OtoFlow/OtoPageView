// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OtoPageView",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "OtoPageView", targets: ["OtoPageView"]),
    ],
    dependencies: [
        .package(url: "https://github.com/siteline/swiftui-introspect", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OtoPageView",
            dependencies: [
                .product(name: "SwiftUIIntrospect", package: "swiftui-introspect"),
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
