//
//  KitoMapsLibreTests.swift
//  KitoMapsLibre
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import SwiftUI
import MapLibre
import KitoMaps
@testable import KitoMapsLibre

@MainActor
final class KitoMapsLibreTests: XCTestCase {
    private let diani = CLLocationCoordinate2D(latitude: -4.2797, longitude: 39.5947)

    func testPresetsPointAtFreeKeylessStyles() {
        XCTAssertEqual(KitoLibreStyle.liberty.url().absoluteString, "https://tiles.openfreemap.org/styles/liberty")
        XCTAssertEqual(KitoLibreStyle.bright.url().absoluteString, "https://tiles.openfreemap.org/styles/bright")
        XCTAssertEqual(KitoLibreStyle.positron.url().absoluteString, "https://tiles.openfreemap.org/styles/positron")
        XCTAssertEqual(KitoLibreStyle.demo.url().absoluteString, "https://demotiles.maplibre.org/style.json")
        XCTAssertEqual(KitoLibreStyle.automatic.url(for: .dark), KitoLibreStyle.dark.url())
        XCTAssertEqual(KitoLibreStyle.automatic.url(for: .light), KitoLibreStyle.liberty.url())
        for style in KitoLibreStyle.presets {
            XCTAssertFalse(style.url().absoluteString.contains("key="), style.title)
        }
    }

    func testAttributionCreditsOpenStreetMap() {
        XCTAssertTrue(KitoLibreStyle.liberty.attribution.contains("OpenStreetMap contributors"))
        XCTAssertTrue(KitoLibreStyle.liberty.attribution.contains("OpenFreeMap"))
        XCTAssertTrue(KitoLibreStyle.liberty.attributionLinks.contains { $0.url.absoluteString == "https://www.openstreetmap.org/copyright" })
        let custom = KitoLibreStyle.custom(URL(fileURLWithPath: "/style.json"), attribution: "© Me")
        XCTAssertEqual(custom.attribution, "© Me")
    }

    func testCircleOverlayBecomesAClosedPolygon() throws {
        let overlay = KitoMapOverlay.circle(center: diani, radius: 1_000, id: "reef")
        let polygon = try XCTUnwrap(KitoLibreOverlayLayers.shape(for: overlay) as? MLNPolygonFeature)
        XCTAssertEqual(polygon.pointCount, 65)
        XCTAssertEqual(KitoLibreOverlayLayers.sourceID("reef"), "kito-overlay-reef")
    }

    func testPolylineOverlayKeepsItsPoints() throws {
        let path = [diani, CLLocationCoordinate2D(latitude: -4.30, longitude: 39.58)]
        let line = try XCTUnwrap(KitoLibreOverlayLayers.shape(for: .polyline(path)) as? MLNPolylineFeature)
        XCTAssertEqual(line.pointCount, 2)
    }

    func testSharesTheKitoMapModifiers() {
        let pin = KitoMapPin(id: "diani", coordinate: diani, title: "Diani Beach", style: .icon("beach.umbrella.fill"))
        let map = KitoLibreMapView(pins: [pin], style: .positron).clustering().controls([.styleSwitcher]).showsUserLocation()
        XCTAssertNotNil(map.options.clusterer)
        XCTAssertEqual(map.options.controls, [.styleSwitcher])
        XCTAssertTrue(map.options.showsUserLocation)
    }

    func testPresetsHaveTitlesAndSymbols() {
        XCTAssertTrue(KitoLibreStyle.presets.allSatisfy { !$0.title.isEmpty && UIImage(systemName: $0.systemImage) != nil })
    }
}
