//
//  KitoLibreMapView.swift
//  KitoMapsLibre
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import MapLibre
import KitoCore
@_spi(KitoMapsProvider) import KitoMaps

/// A MapLibre map — free OpenStreetMap tiles, no API key — with Kito pins, clusters, routes,
/// circles, floating controls, an attribution label and an optional card carousel. Same
/// arguments and modifiers as `KitoMapView`, so switching is a one-line change.
///
/// ```swift
/// KitoLibreMapView(pins: places, selection: $selected, style: .liberty) { pin in
///     KitoMapPinCard(pin: pin)
/// }
/// .clustering()
/// ```
public struct KitoLibreMapView<Card: View>: View, KitoMapConfigurable {
    public var options = KitoMapOptions()

    let pins: [KitoMapPin]
    let externalSelection: Binding<String?>?
    let initialStyle: KitoLibreStyle
    let camera: KitoMapCamera
    let controller: KitoMapController?
    let card: ((KitoMapPin) -> Card)?

    @State private var style: KitoLibreStyle
    @State private var is3D = false
    @State private var localSelection: String?
    @State private var bottomInset: CGFloat = 0
    @State private var ownController = KitoMapController()

    @Environment(\.kitoTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    /// - Parameters:
    ///   - pins: The places to show.
    ///   - selection: The selected pin's id. Tapping a pin or swiping the cards changes it.
    ///   - style: The starting map style; the style switcher can change it.
    ///   - camera: Where the camera starts. Defaults to framing every pin.
    ///   - controller: Moves the camera from outside.
    ///   - card: A card per pin, shown in a carousel along the bottom.
    public init(pins: [KitoMapPin], selection: Binding<String?>? = nil, style: KitoLibreStyle = .automatic,
                camera: KitoMapCamera = .fitPins, controller: KitoMapController? = nil,
                @ViewBuilder card: @escaping (KitoMapPin) -> Card) {
        self.pins = pins
        self.externalSelection = selection
        self.initialStyle = style
        self.camera = camera
        self.controller = controller
        self.card = card
        self._style = State(initialValue: style)
    }

    private var selection: Binding<String?> { externalSelection ?? $localSelection }
    private var activeController: KitoMapController { controller ?? ownController }

    public var body: some View {
        KitoMapScaffold(pins: pins, selection: selection, options: options, style: $style, is3D: $is3D,
                        bottomInset: $bottomInset, controller: activeController, card: card) {
            KitoLibreMapRepresentable(
                pins: pins, selection: selection, options: options, style: style, is3D: is3D,
                bottomInset: bottomInset, initialCamera: camera, request: activeController.request,
                controller: activeController, theme: theme, colorScheme: colorScheme, displayScale: displayScale)
                .overlay(alignment: .bottomLeading) {
                    KitoLibreAttribution(style: style)
                        .padding(.leading, theme.spacing.sm)
                        .padding(.bottom, bottomInset + theme.spacing.xs)
                }
        }
        .onAppear { if options.startsIn3D { is3D = true } }
        .onChange(of: initialStyle) { _, newStyle in style = newStyle }
    }
}

public extension KitoLibreMapView where Card == EmptyView {
    /// A map without the card carousel.
    init(pins: [KitoMapPin], selection: Binding<String?>? = nil, style: KitoLibreStyle = .automatic,
         camera: KitoMapCamera = .fitPins, controller: KitoMapController? = nil) {
        self.pins = pins
        self.externalSelection = selection
        self.initialStyle = style
        self.camera = camera
        self.controller = controller
        self.card = nil
        self._style = State(initialValue: style)
    }
}

// MARK: - Attribution

/// The credit line OpenStreetMap's licence asks for. Tap it for links.
public struct KitoLibreAttribution: View {
    let style: KitoLibreStyle
    @Environment(\.kitoTheme) private var theme
    @Environment(\.openURL) private var openURL

    public init(style: KitoLibreStyle) {
        self.style = style
    }

    public var body: some View {
        Menu {
            ForEach(style.attributionLinks, id: \.url) { link in
                Button(link.title, systemImage: "arrow.up.forward.square") { openURL(link.url) }
            }
        } label: {
            Text(style.attribution)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.colors.onSurface.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, theme.spacing.sm)
                .padding(.vertical, theme.spacing.xxs + 1)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel("Map data \(style.attribution)")
        .accessibilityHint("Shows the data sources")
    }
}

// MARK: - Representable

struct KitoLibreMapRepresentable: UIViewRepresentable {
    let pins: [KitoMapPin]
    let selection: Binding<String?>
    let options: KitoMapOptions
    let style: KitoLibreStyle
    let is3D: Bool
    let bottomInset: CGFloat
    let initialCamera: KitoMapCamera
    let request: KitoCameraRequest?
    let controller: KitoMapController
    let theme: KitoTheme
    let colorScheme: ColorScheme
    let displayScale: CGFloat

    func makeCoordinator() -> KitoLibreMapCoordinator {
        KitoLibreMapCoordinator(self)
    }

    func makeUIView(context: Context) -> KitoLibreContainerView {
        context.coordinator.layoutDirection = context.environment.layoutDirection
        return context.coordinator.container
    }

    func updateUIView(_ uiView: KitoLibreContainerView, context: Context) {
        context.coordinator.layoutDirection = context.environment.layoutDirection
        context.coordinator.update(self)
    }
}

/// Hosts the map and reports layout, so the first camera fit happens once there is a size.
final class KitoLibreContainerView: UIView {
    let mapView: MLNMapView
    var onLayout: (() -> Void)?

    init(styleURL: URL) {
        mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        super.init(frame: .zero)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(mapView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapView.frame = bounds
        onLayout?()
    }
}

/// A point annotation that remembers which Kito item it draws.
final class KitoLibreAnnotation: MLNPointAnnotation {
    var itemID = ""
}

/// Draws a Kito pin image inside a MapLibre annotation view.
final class KitoLibreAnnotationView: MLNAnnotationView {
    let content = KitoMarkerContentView()

    override init(annotation: MLNAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        scalesWithViewingDistance = false
        rotatesToMatchCamera = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show(_ rendered: KitoPinImage, bounce: Bool, pulseColor: UIColor?, pulseDiameter: CGFloat) {
        content.show(rendered, bounce: bounce, pulseColor: pulseColor, pulseDiameter: pulseDiameter)
        let size = rendered.image.size
        bounds = CGRect(origin: .zero, size: size)
        content.frame = bounds
        centerOffset = CGVector(dx: (0.5 - rendered.anchor.x) * size.width, dy: (0.5 - rendered.anchor.y) * size.height)
    }
}

// MARK: - Coordinator

@MainActor
final class KitoLibreMapCoordinator: NSObject {
    private(set) var parent: KitoLibreMapRepresentable
    /// Maps `fitPadding`'s leading/trailing onto the map's physical left/right.
    var layoutDirection: LayoutDirection = .leftToRight
    let container: KitoLibreContainerView
    private var mapView: MLNMapView { container.mapView }

    private var annotations: [String: KitoLibreAnnotation] = [:]
    private var markerKeys: [String: String] = [:]
    private var items: [KitoMapCluster] = []
    private var pendingOrigins: [String: CLLocationCoordinate2D] = [:]
    private var drawnOverlays: [KitoMapOverlay] = []
    private var drawnOverlayIDs: Set<String> = []
    private var isStyleLoaded = false
    private var zoomLevel: Int?
    private var hasPlacedCamera = false
    private var lastRequestID: Int?
    private var lastSelection: String?
    private var lastStyleURL: URL?
    private var lastScheme: ColorScheme?
    private var lastIs3D = false
    private var lastInset: CGFloat = -1
    private var location: KitoLocationProvider?
    private var avatars: [URL: UIImage] = [:]
    private var loadingAvatars: Set<URL> = []

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    init(_ parent: KitoLibreMapRepresentable) {
        self.parent = parent
        let url = parent.style.url(for: parent.colorScheme)
        container = KitoLibreContainerView(styleURL: url)
        lastStyleURL = url
        lastScheme = parent.colorScheme
        super.init()
        mapView.delegate = self
        mapView.automaticallyAdjustsContentInset = false
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.compassViewPosition = .topLeft
        mapView.backgroundColor = .secondarySystemBackground
        lastSelection = parent.selection.wrappedValue
        lastRequestID = parent.request?.id
        container.onLayout = { [weak self] in self?.placeInitialCamera() }
    }

    /// MapLibre zoom levels use 512-point tiles; Kito zooms use 256.
    private var kitoZoom: Double { mapView.zoomLevel + 1 }

    func update(_ newParent: KitoLibreMapRepresentable) {
        parent = newParent
        if parent.bottomInset != lastInset {
            lastInset = parent.bottomInset
            mapView.setContentInset(UIEdgeInsets(top: 0, left: 0, bottom: parent.bottomInset, right: 0), animated: false, completionHandler: nil)
        }
        applyStyle()
        applyUserLocation()
        syncOverlays()

        let selection = parent.selection.wrappedValue
        let selectionChanged = selection != lastSelection
        lastSelection = selection
        if hasPlacedCamera { syncMarkers() }
        if selectionChanged, parent.options.followsSelection { follow(selection) }

        if parent.is3D != lastIs3D {
            lastIs3D = parent.is3D
            tilt(parent.is3D)
        }
        if let request = parent.request, request.id != lastRequestID {
            lastRequestID = request.id
            apply(request.camera, animated: request.animated)
        }
        placeInitialCamera()
    }

    // MARK: Camera

    private func placeInitialCamera() {
        guard !hasPlacedCamera, container.bounds.width > 0, container.bounds.height > 0 else { return }
        if case .fitPins = parent.initialCamera, parent.pins.isEmpty, parent.options.overlays.isEmpty { return }
        hasPlacedCamera = true
        apply(parent.initialCamera, animated: false)
        zoomLevel = Int(floor(kitoZoom))
        syncMarkers()
    }

    private func apply(_ camera: KitoMapCamera, animated: Bool) {
        switch camera {
        case .fitPins:
            let pins = parent.pins.map(\.coordinate)
            fit(pins.isEmpty ? parent.options.overlays.flatMap(\.fittingCoordinates) : pins, animated: animated)
        case .fit(let coordinates):
            fit(coordinates, animated: animated)
        case .center(let coordinate, let zoom):
            let target = mapView.camera
            target.centerCoordinate = coordinate
            move(to: target, zoom: zoom - 1, animated: animated)
        case .userLocation(let zoom):
            locate(zoom: zoom)
        }
    }

    private func fit(_ coordinates: [CLLocationCoordinate2D], animated: Bool, maximumZoom: Double = 16) {
        guard let first = coordinates.first else { return }
        var sw = first, ne = first
        for coordinate in coordinates {
            sw.latitude = min(sw.latitude, coordinate.latitude); sw.longitude = min(sw.longitude, coordinate.longitude)
            ne.latitude = max(ne.latitude, coordinate.latitude); ne.longitude = max(ne.longitude, coordinate.longitude)
        }
        let padding = parent.options.fitPadding
        let isRTL = layoutDirection == .rightToLeft
        let insets = UIEdgeInsets(top: padding.top, left: isRTL ? padding.trailing : padding.leading,
                                  bottom: padding.bottom, right: isRTL ? padding.leading : padding.trailing)
        let camera = mapView.cameraThatFitsCoordinateBounds(MLNCoordinateBoundsMake(sw, ne), edgePadding: insets)
        let fitted = MLNZoomLevelForAltitude(camera.altitude, camera.pitch, camera.centerCoordinate.latitude, mapView.bounds.size)
        let zoom = min(fitted, maximumZoom - 1)
        move(to: camera, zoom: zoom, animated: animated)
    }

    private func move(to camera: MLNMapCamera, zoom: Double? = nil, animated: Bool) {
        if let zoom {
            camera.altitude = MLNAltitudeForZoomLevel(zoom, camera.pitch, camera.centerCoordinate.latitude, mapView.bounds.size)
        }
        mapView.setCamera(camera, withDuration: animated && !reduceMotion ? 0.8 : 0,
                          animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))
    }

    private func follow(_ id: String?) {
        guard let id, let pin = parent.pins.first(where: { $0.id == id }) else { return }
        let camera = mapView.camera
        camera.centerCoordinate = pin.coordinate
        move(to: camera, animated: true)
    }

    private func tilt(_ on: Bool) {
        let camera = mapView.camera
        camera.pitch = on ? 60 : 0
        camera.heading = on ? camera.heading + 20 : 0
        move(to: camera, zoom: on ? max(mapView.zoomLevel, 15) : nil, animated: true)
    }

    private func locate(zoom: Double) {
        let provider = location ?? KitoLocationProvider()
        location = provider
        provider.locate { [weak self] found in
            guard let self, let found else { return }
            self.mapView.showsUserLocation = true
            let camera = self.mapView.camera
            camera.centerCoordinate = found.coordinate
            self.move(to: camera, zoom: zoom - 1, animated: true)
        }
    }

    // MARK: Style and location

    private func applyStyle() {
        let url = parent.style.url(for: parent.colorScheme)
        if url != lastStyleURL {
            lastStyleURL = url
            isStyleLoaded = false
            drawnOverlayIDs = []
            mapView.styleURL = url
        }
        if parent.colorScheme != lastScheme {
            lastScheme = parent.colorScheme
            refreshAllMarkers()
        }
    }

    private func applyUserLocation() {
        guard parent.options.showsUserLocation, !mapView.showsUserLocation else { return }
        let provider = location ?? KitoLocationProvider()
        location = provider
        if provider.isAuthorized {
            mapView.showsUserLocation = true
        } else if provider.authorization == .notDetermined {
            provider.locate { [weak self] found in if found != nil { self?.mapView.showsUserLocation = true } }
        }
    }

    // MARK: Overlays

    private func syncOverlays() {
        guard isStyleLoaded, let style = mapView.style else { return }
        let overlays = parent.options.overlays
        guard overlays != drawnOverlays else { return }
        drawnOverlays = overlays
        let ids = Set(overlays.map(\.id))
        for id in drawnOverlayIDs where !ids.contains(id) {
            KitoLibreOverlayLayers.remove(id, from: style)
        }
        for overlay in overlays {
            KitoLibreOverlayLayers.draw(overlay, in: style)
        }
        drawnOverlayIDs = ids
    }

    // MARK: Markers

    private func syncMarkers() {
        let selection = parent.selection.wrappedValue
        let newItems = parent.options.clusterer?.clusters(for: parent.pins, zoom: kitoZoom, excluding: selection)
            ?? parent.pins.map { KitoMapCluster(pins: [$0]) }
        let diff = KitoClusterDiff(from: items, to: newItems)
        let firstReveal = items.isEmpty

        for item in diff.removed {
            guard let annotation = annotations.removeValue(forKey: item.id) else { continue }
            markerKeys[item.id] = nil
            retire(annotation, to: diff.mergeTargets[item.id])
        }
        for item in diff.kept {
            guard let annotation = annotations[item.id] else { continue }
            if annotation.coordinate.latitude != item.coordinate.latitude || annotation.coordinate.longitude != item.coordinate.longitude {
                annotation.coordinate = item.coordinate
            }
            if let view = mapView.view(for: annotation) as? KitoLibreAnnotationView {
                configure(view, item: item, bounce: true)
            }
        }
        var added: [KitoLibreAnnotation] = []
        for (index, item) in diff.inserted.enumerated() {
            let annotation = KitoLibreAnnotation()
            annotation.itemID = item.id
            annotation.coordinate = item.coordinate
            annotation.title = item.pin?.title
            annotations[item.id] = annotation
            if let origin = diff.origins[item.id] { pendingOrigins[item.id] = origin }
            pendingDelays[item.id] = firstReveal ? min(Double(index) * 0.025, 0.45) : 0
            added.append(annotation)
        }
        items = newItems
        if !added.isEmpty { mapView.addAnnotations(added) }
    }

    private var pendingDelays: [String: TimeInterval] = [:]

    private func refreshAllMarkers() {
        for item in items {
            guard let annotation = annotations[item.id], let view = mapView.view(for: annotation) as? KitoLibreAnnotationView else { continue }
            markerKeys[item.id] = nil
            configure(view, item: item, bounce: false)
        }
    }

    private func configure(_ view: KitoLibreAnnotationView, item: KitoMapCluster, bounce: Bool) {
        let selected = item.pin?.id == parent.selection.wrappedValue
        view.layer.zPosition = selected ? 1_000 : (item.isCluster ? 500 : 0)
        view.accessibilityLabel = item.pin?.accessibilityText ?? "\(item.count) places"
        view.accessibilityHint = item.isCluster ? "Zooms in to show them" : "Shows this place"
        view.accessibilityTraits = selected ? [.button, .selected] : .button
        let key = item.visualKey(selected: selected) + "|\(parent.colorScheme)" + (item.pin.flatMap(avatarURL).flatMap { avatars[$0] } == nil ? "" : "|img")
        guard markerKeys[item.id] != key else { return }
        let hadImage = markerKeys[item.id] != nil
        markerKeys[item.id] = key

        let rendered: KitoPinImage?
        if let pin = item.pin {
            let avatar = avatarURL(pin).flatMap { url -> UIImage? in
                if let image = avatars[url] { return image }
                load(url)
                return nil
            }
            rendered = KitoPinRenderer.image(for: pin, selected: selected, theme: parent.theme, colorScheme: parent.colorScheme,
                                             avatarImage: avatar, displayScale: parent.displayScale)
        } else {
            rendered = KitoPinRenderer.clusterImage(count: item.count, tint: item.sharedTint, theme: parent.theme,
                                                    colorScheme: parent.colorScheme, displayScale: parent.displayScale)
        }
        guard let rendered else { return }
        let pulse = item.pin.flatMap { pin in pin.pulseDiameter.map { (UIColor(pin.tint ?? parent.theme.colors.primary), $0) } }
        view.show(rendered, bounce: bounce && hadImage, pulseColor: pulse?.0, pulseDiameter: pulse?.1 ?? 34)
    }

    private func retire(_ annotation: KitoLibreAnnotation, to target: CLLocationCoordinate2D?) {
        guard let view = mapView.view(for: annotation) as? KitoLibreAnnotationView else {
            mapView.removeAnnotation(annotation)
            return
        }
        if let target, !reduceMotion {
            let from = mapView.convert(annotation.coordinate, toPointTo: mapView)
            let to = mapView.convert(target, toPointTo: mapView)
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
                view.content.transform = CGAffineTransform(translationX: to.x - from.x, y: to.y - from.y).scaledBy(x: 0.6, y: 0.6)
                view.content.alpha = 0
            } completion: { [weak self] _ in
                self?.mapView.removeAnnotation(annotation)
            }
        } else {
            view.content.shrinkAway { [weak self] in self?.mapView.removeAnnotation(annotation) }
        }
    }

    private func avatarURL(_ pin: KitoMapPin) -> URL? {
        if case .avatar(_, let url) = pin.style { return url }
        return nil
    }

    private func load(_ url: URL) {
        guard !loadingAvatars.contains(url) else { return }
        loadingAvatars.insert(url)
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { return }
            self?.avatars[url] = image
            self?.refreshAllMarkers()
        }
    }

    fileprivate func item(for annotation: MLNAnnotation) -> KitoMapCluster? {
        guard let annotation = annotation as? KitoLibreAnnotation else { return nil }
        return items.first { $0.id == annotation.itemID }
    }
}

extension KitoLibreMapCoordinator: @preconcurrency MLNMapViewDelegate {
    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        isStyleLoaded = true
        drawnOverlays = []
        drawnOverlayIDs = []
        syncOverlays()
    }

    func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        guard let annotation = annotation as? KitoLibreAnnotation, let item = item(for: annotation) else { return nil }
        let view = KitoLibreAnnotationView(annotation: annotation, reuseIdentifier: nil)
        configure(view, item: item, bounce: false)
        let delay = pendingDelays.removeValue(forKey: item.id) ?? 0
        if let origin = pendingOrigins.removeValue(forKey: item.id), !reduceMotion {
            let from = mapView.convert(origin, toPointTo: mapView)
            let to = mapView.convert(item.coordinate, toPointTo: mapView)
            view.content.transform = CGAffineTransform(translationX: from.x - to.x, y: from.y - to.y)
            UIView.animate(withDuration: 0.5, delay: delay, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
                view.content.transform = .identity
            }
        }
        view.content.popIn(delay: delay)
        return view
    }

    func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
        false
    }

    func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
        mapView.deselectAnnotation(annotation, animated: false)
        guard let item = item(for: annotation) else { return }
        if let pin = item.pin {
            withAnimation(reduceMotion ? nil : .snappy) { parent.selection.wrappedValue = pin.id }
        } else {
            fit(item.pins.map(\.coordinate), animated: true, maximumZoom: 18)
        }
    }

    func mapViewRegionIsChanging(_ mapView: MLNMapView) {
        let level = Int(floor(kitoZoom))
        guard hasPlacedCamera, level != zoomLevel else { return }
        zoomLevel = level
        syncMarkers()
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        parent.controller.report(center: mapView.centerCoordinate, zoom: kitoZoom)
        mapViewRegionIsChanging(mapView)
    }
}

// MARK: - Overlays as style layers

/// Draws `KitoMapOverlay`s as MapLibre sources and layers.
enum KitoLibreOverlayLayers {
    static func sourceID(_ id: String) -> String { "kito-overlay-\(id)" }
    static func lineID(_ id: String) -> String { "kito-overlay-\(id)-line" }
    static func fillID(_ id: String) -> String { "kito-overlay-\(id)-fill" }

    /// The shape MapLibre draws for an overlay.
    static func shape(for overlay: KitoMapOverlay) -> MLNShape {
        switch overlay.shape {
        case .polyline(let coordinates):
            return MLNPolylineFeature(coordinates: coordinates, count: UInt(coordinates.count))
        case .circle(let center, let radius):
            let ring = KitoMapGeometry.circle(center: center, radius: radius)
            return MLNPolygonFeature(coordinates: ring, count: UInt(ring.count))
        }
    }

    @MainActor
    static func draw(_ overlay: KitoMapOverlay, in style: MLNStyle) {
        let shape = shape(for: overlay)
        if let source = style.source(withIdentifier: sourceID(overlay.id)) as? MLNShapeSource {
            source.shape = shape
        } else {
            let source = MLNShapeSource(identifier: sourceID(overlay.id), shape: shape, options: nil)
            style.addSource(source)
            if case .circle = overlay.shape {
                let fill = MLNFillStyleLayer(identifier: fillID(overlay.id), source: source)
                style.addLayer(fill)
            }
            style.addLayer(MLNLineStyleLayer(identifier: lineID(overlay.id), source: source))
        }
        let color = UIColor(overlay.color)
        if let fill = style.layer(withIdentifier: fillID(overlay.id)) as? MLNFillStyleLayer {
            fill.fillColor = NSExpression(forConstantValue: color)
            fill.fillOpacity = NSExpression(forConstantValue: 0.16)
        }
        if let line = style.layer(withIdentifier: lineID(overlay.id)) as? MLNLineStyleLayer {
            line.lineColor = NSExpression(forConstantValue: color)
            line.lineWidth = NSExpression(forConstantValue: overlay.lineWidth)
            line.lineCap = NSExpression(forConstantValue: "round")
            line.lineJoin = NSExpression(forConstantValue: "round")
            line.lineDashPattern = overlay.isDashed ? NSExpression(forConstantValue: [0.01, 2]) : nil
        }
    }

    @MainActor
    static func remove(_ id: String, from style: MLNStyle) {
        for layerID in [lineID(id), fillID(id)] {
            if let layer = style.layer(withIdentifier: layerID) { style.removeLayer(layer) }
        }
        if let source = style.source(withIdentifier: sourceID(id)) { style.removeSource(source) }
    }
}
