// swift-tools-version: 5.9
//
//  Package.swift
//  KitoMapsLibre
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoMapsLibre",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoMapsLibre", targets: ["KitoMapsLibre"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoMaps.git", from: "0.2.0"),
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution", from: "6.31.0"),
    ],
    targets: [
        .target(name: "KitoMapsLibre", dependencies: [
            .product(name: "KitoMaps", package: "KitoMaps"),
            .product(name: "MapLibre", package: "maplibre-gl-native-distribution"),
        ]),
        .testTarget(name: "KitoMapsLibreTests", dependencies: ["KitoMapsLibre"]),
    ]
)
