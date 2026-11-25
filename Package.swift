// swift-tools-version: 5.9

import PackageDescription

// 封装版本 = 基础库 UMCommon 的版本（见 docs/adr/0001-package-version-follows-umcommon.md）。
// 以下四个常量由 scripts/bump.sh 改写，请勿手动改动格式。
let umCommonVersion = "7.7.0"
let umCommonChecksum = "f8f3d3fdf467a0268e486f83731630c1a9457df0fb2c8f769a953cdecf4f4421"
let umDeviceVersion = "3.6.0"
let umDeviceChecksum = "d2cda7bec252a5a425cbf079589147854ca56afaa007adcc2c25f7ed8cbde04c"

// 只引用友盟官方制品，不转存二进制（见 docs/adr/0002-reference-official-artifacts-only.md）。
let officialArtifactBaseURL = "https://umplus-sdk-download.oss-cn-shanghai.aliyuncs.com/iOS"

let package = Package(
    name: "UMengSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "UMCommon",
            targets: ["UMCommon", "UMDevice", "UMCommonLinkage"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "UMCommon",
            url: "\(officialArtifactBaseURL)/UMCommon/UMCommon_\(umCommonVersion).zip",
            checksum: umCommonChecksum
        ),
        .binaryTarget(
            name: "UMDevice",
            url: "\(officialArtifactBaseURL)/UMDevice/UMDevice_\(umDeviceVersion).zip",
            checksum: umDeviceChecksum
        ),
        // 二进制 target 无法声明链接设置，由该空源码 target 代为声明 UMCommon 所需的系统库。
        .target(
            name: "UMCommonLinkage",
            path: "Sources/UMCommonLinkage",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedLibrary("z"),
                .linkedFramework("CoreTelephony"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .testTarget(
            name: "UMCommonSmokeTests",
            dependencies: ["UMCommon", "UMDevice", "UMCommonLinkage"],
            path: "Tests/UMCommonSmokeTests"
        )
    ]
)
