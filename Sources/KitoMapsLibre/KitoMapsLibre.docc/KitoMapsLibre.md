# ``KitoMapsLibre``

KitoMaps pins, clusters, cards, routes and controls on free OpenStreetMap maps through MapLibre Native.

## Overview

KitoMapsLibre brings the KitoMaps API to MapLibre Native, with no account, API key or billing.
``KitoLibreMapView`` takes the same arguments as `KitoMapView` from KitoMaps — an array of
`KitoMapPin` values, a selection binding, `camera:`, `controller:` and an optional card builder —
and supports the same configuration methods, including `clustering()`, `overlays(_:)` and
`controls(_:)`. Switching provider is a one-line change.

```swift
import SwiftUI
import KitoMaps
import KitoMapsLibre

struct ContentView: View {
    @State private var selected: String?
    let places: [KitoMapPin]

    var body: some View {
        KitoLibreMapView(pins: places, selection: $selected, style: .liberty) { pin in
            KitoMapPinCard(pin: pin)
        }
        .clustering()
        .controls(.all)
    }
}
```

Routes and circles are drawn as MapLibre style layers, so they stay crisp and sit under the pins.
``KitoLibreStyle`` includes the keyless OpenFreeMap styles (Liberty, Bright, Positron and Dark),
the MapLibre demo tiles, an automatic light and dark choice, and `custom(_:attribution:)` for any
MapLibre style JSON, such as your own tiles.

OpenStreetMap data is licensed under the ODbL, which requires visible credit. The map shows a
small attribution label above the cards; keep it visible. ``KitoLibreAttribution`` is the same
label, for when you build your own chrome.

## Topics

### Essentials

- ``KitoLibreMapView``

### Styles and Attribution

- ``KitoLibreStyle``
- ``KitoLibreAttribution``
