// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "30DayChallenge",
    platforms: [
        .iOS(.v17)
    ],
    products: [],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.2.0")
    ],
    targets: []
)
