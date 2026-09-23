//
//  KitoLibreStyle.swift
//  KitoMapsLibre
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoMaps

/// Free, keyless map styles for MapLibre. The OpenFreeMap styles use OpenStreetMap data served by
/// [OpenFreeMap](https://openfreemap.org) — no account, no API key, no usage limits for fair use.
public enum KitoLibreStyle: Hashable, Sendable, KitoMapStyleOption {
    /// Liberty in light mode, Dark in dark mode.
    case automatic
    /// OpenFreeMap Liberty: colourful and detailed, with 3D buildings when tilted.
    case liberty
    /// OpenFreeMap Bright: vivid, high contrast.
    case bright
    /// OpenFreeMap Positron: pale greys that let pins stand out.
    case positron
    /// OpenFreeMap Dark.
    case dark
    /// The MapLibre demo tiles: a simple world map, handy for tests.
    case demo
    /// Any MapLibre style JSON URL — your own tiles, MapTiler, Stadia, Protomaps…
    /// Pass `attribution` for the data it shows.
    case custom(URL, attribution: String = "© OpenStreetMap contributors")

    public static var presets: [KitoLibreStyle] { [.automatic, .liberty, .bright, .positron, .dark, .demo] }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .liberty: return "Liberty"
        case .bright: return "Bright"
        case .positron: return "Positron"
        case .dark: return "Dark"
        case .demo: return "Demo"
        case .custom: return "Custom"
        }
    }

    public var systemImage: String {
        switch self {
        case .automatic: return "circle.lefthalf.filled"
        case .liberty: return "map"
        case .bright: return "sun.max.fill"
        case .positron: return "map.circle"
        case .dark: return "moon.stars.fill"
        case .demo: return "globe.europe.africa.fill"
        case .custom: return "paintpalette"
        }
    }

    /// The style JSON URL for a colour scheme.
    public func url(for colorScheme: ColorScheme = .light) -> URL {
        switch self {
        case .automatic: return colorScheme == .dark ? Self.openFreeMap("dark") : Self.openFreeMap("liberty")
        case .liberty: return Self.openFreeMap("liberty")
        case .bright: return Self.openFreeMap("bright")
        case .positron: return Self.openFreeMap("positron")
        case .dark: return Self.openFreeMap("dark")
        case .demo: return Self.demoURL
        case .custom(let url, _): return url
        }
    }

    /// The credit line the data licence requires on screen.
    public var attribution: String {
        switch self {
        case .demo: return "© MapLibre · Natural Earth"
        case .custom(_, let attribution): return attribution
        default: return "© OpenFreeMap · © OpenMapTiles · © OpenStreetMap contributors"
        }
    }

    /// Where the credit links go.
    public var attributionLinks: [(title: String, url: URL)] {
        switch self {
        case .demo:
            return [("MapLibre", Self.link("https://maplibre.org")), ("Natural Earth", Self.link("https://www.naturalearthdata.com"))]
        case .custom:
            return [("OpenStreetMap", Self.link("https://www.openstreetmap.org/copyright"))]
        default:
            return [("OpenFreeMap", Self.link("https://openfreemap.org")),
                    ("OpenMapTiles", Self.link("https://openmaptiles.org")),
                    ("OpenStreetMap contributors", Self.link("https://www.openstreetmap.org/copyright"))]
        }
    }

    private static func openFreeMap(_ name: String) -> URL {
        link("https://tiles.openfreemap.org/styles/" + name)
    }

    private static let demoURL = link("https://demotiles.maplibre.org/style.json")

    private static func link(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }
}
