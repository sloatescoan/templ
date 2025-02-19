// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "Templ",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "Templ", targets: ["Templ"]),
    .library(name: "HummingbirdTempl", targets: ["HummingbirdTempl"])
  ],
  dependencies: [
    .package(url: "https://github.com/kylef/Spectre.git", from: "0.10.1"),
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0")
  ],
  targets: [
    .target(
      name: "Templ"
    ),
    .target(
      name: "HummingbirdTempl",
      dependencies: [
        "Templ",
        .product(name: "Hummingbird", package: "hummingbird")
      ]
    ),
    .testTarget(name: "TemplTests", dependencies: [
      "Templ",
      "Spectre"
    ])
  ],
  swiftLanguageModes: [.v6]
)
