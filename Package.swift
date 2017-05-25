// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "imastodondon",
    dependencies: [
        .Package(url: "https://github.com/ikesyo/Himotoki", majorVersion: 3),
        .Package(url: "https://github.com/onevcat/Kingfisher", majorVersion: 3)]
)
