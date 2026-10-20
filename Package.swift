// swift-tools-version: 6.0
//
// LongNote — a data-driven rich text / multimedia card editor component library,
// rebuilt in SwiftUI from the classic "Weico Long Article" editor with all
// networking and platform integration stripped out.
//
// Two targets:
//   - LongNoteCore: platform-independent model, paragraph-mutation algorithms and
//     file storage. No UIKit/SwiftUI, so `swift test --target LongNoteTests` runs
//     on Linux/Windows too.
//   - LongNote:     the iOS editor + long-image renderer. Depends on LongNoteCore.
//
// swift-tools-version 6.0 is required for `.iOS(.v18)` (PackageDescription 6.0);
// the language mode is pinned to Swift 5 to keep the UI layer's concurrency
// annotations lenient.
import PackageDescription

let package = Package(
    name: "LongNote",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "LongNote", targets: ["LongNote"])
    ],
    targets: [
        .target(
            name: "LongNoteCore",
            path: "Sources/LongNoteCore"
        ),
        .target(
            name: "LongNote",
            dependencies: ["LongNoteCore"],
            path: "Sources/LongNote"
        ),
        .testTarget(
            name: "LongNoteTests",
            dependencies: ["LongNoteCore"],
            path: "Tests/LongNoteTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
