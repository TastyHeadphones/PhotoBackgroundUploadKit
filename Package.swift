// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PhotoBackgroundUploadKit",
    platforms: [
        .iOS("26.1")
    ],
    products: [
        .library(
            name: "PhotoBackgroundUploadKit",
            targets: ["PhotoBackgroundUploadKit"]
        ),
    ],
    targets: [
        .target(
            name: "PhotoBackgroundUploadKit",
            swiftSettings: [
                .define("PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "PhotoBackgroundUploadKitHostSample",
            dependencies: [
                "PhotoBackgroundUploadKit"
            ],
            path: "Examples/HostApp",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "PhotoBackgroundUploadKitExtensionSample",
            dependencies: [
                "PhotoBackgroundUploadKit"
            ],
            path: "Examples/BackgroundUploadExtension",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PhotoBackgroundUploadKitTests",
            dependencies: ["PhotoBackgroundUploadKit"]
        ),
    ]
)
