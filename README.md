# KitoMapsLibre

[KitoMaps](https://github.com/WykSofts-Inc/KitoMaps) on [MapLibre Native](https://maplibre.org): the
same pins, clusters, cards, routes and controls as `KitoMapView`, on free OpenStreetMap maps. No
account, no API key, no billing. Part of the [Kito](https://github.com/WykSofts-Inc/KitoDevKit)
ecosystem.

## A map with cards

```swift
import KitoMapsLibre

@State private var selected: String?

KitoLibreMapView(pins: places, selection: $selected, style: .liberty) { pin in
    KitoMapPinCard(pin: pin)
}
.clustering()
.controls(.all)
.overlays([.route(route, color: .blue), .circle(center: store, radius: 2_000, color: .orange)])
```

It is `KitoMapView` with a different name: same `KitoMapPin`s, `selection`, `camera:`,
`controller:`, card builder and modifiers, so switching provider is a one-line change. Routes and
circles are drawn as MapLibre style layers, so they stay crisp and sit under the pins.

## Free styles

| Style | Source |
|---|---|
| `.automatic` | Liberty in light mode, Dark in dark mode (default) |
| `.liberty` | [OpenFreeMap](https://openfreemap.org) Liberty — colourful, 3D buildings when tilted |
| `.bright` | OpenFreeMap Bright |
| `.positron` | OpenFreeMap Positron — pale greys that let pins pop |
| `.dark` | OpenFreeMap Dark |
| `.demo` | The [MapLibre demo tiles](https://demotiles.maplibre.org) — a simple world map |
| `.custom(url, attribution:)` | Any MapLibre style JSON: your own tiles, MapTiler, Stadia, Protomaps… |

OpenFreeMap is free and keyless with no usage limits for fair use; it runs on donations, so consider
supporting it if your app gets big, or host your own tiles and pass `.custom(url, attribution:)`.

## Attribution

OpenStreetMap data is licensed under the [ODbL](https://www.openstreetmap.org/copyright), which
requires visible credit. The map shows a small label — "© OpenFreeMap · © OpenMapTiles ·
© OpenStreetMap contributors" — in the bottom-left corner, above the cards; tapping it lists the
sources. Keep it visible. `KitoLibreAttribution(style:)` is the same label if you build your own
chrome.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoMapsLibre.git", from: "0.1.0")
```

iOS 17+. Brings in [KitoMaps](https://github.com/WykSofts-Inc/KitoMaps) and MapLibre's
[maplibre-gl-native-distribution](https://github.com/maplibre/maplibre-gl-native-distribution)
package (6.31.0 or later), a dynamic framework of about 8 MB for arm64.

## License

MIT — see [LICENSE](LICENSE). MapLibre Native is BSD-2-Clause; map data © OpenStreetMap
contributors.
