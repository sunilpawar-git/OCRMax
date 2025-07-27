// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OCRMax",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "OCRMax",
            targets: ["OCRMax"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyTesseract/SwiftyTesseract.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "OCRMax",
            dependencies: ["SwiftyTesseract"]),
        .testTarget(
            name: "OCRMaxTests",
            dependencies: ["OCRMax"]),
    ]
)