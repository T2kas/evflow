import SwiftUI
import MapLibre

enum MapMode { case browse, route, nav }

/// Recolours the bundled OpenFreeMap "positron" style to Waze's palette and writes it to a temp file.
/// Waze: near-white ground, mint parks, bright blue water, light-grey roads, grey buildings.
private func wazeStyleURL() -> URL? {
    guard let src = Bundle.main.url(forResource: "positron", withExtension: "json"),
          let data = try? Data(contentsOf: src),
          var style = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let layers = style["layers"] as? [[String: Any]] else { return nil }

    let c = (bg: "#f6f6f5", park: "#bdeec3", wood: "#c4f0c9", residential: "#f6f6f5", water: "#8fd0f4",
             building: "#e3e4e6", buildingLine: "#d4d6d9", casing: "#c9ccd1", road: "#dcdfe3", minorCasing: "#d8dbdf", minor: "#e7e9ec",
             label: "#5f6368", waterLabel: "#2f86c8")
    func width(_ a: Double) -> [Any] { ["interpolate", ["exponential", 1.5], ["zoom"], 12, 0.7 * a, 14, 2.8 * a, 16, 8 * a, 18, 20 * a] }

    var out: [[String: Any]] = []
    for var l in layers {
        let id = l["id"] as? String ?? ""
        var paint = l["paint"] as? [String: Any] ?? [:]
        switch true {
        case id == "background": paint["background-color"] = c.bg
        case id == "park": paint["fill-color"] = c.park
        case id == "landcover_wood": paint["fill-color"] = c.wood; paint["fill-opacity"] = 1
        case id == "landuse_residential": paint["fill-color"] = c.residential
        case id == "water": paint["fill-color"] = c.water
        case id == "waterway": paint["line-color"] = c.water
        case id == "building": paint["fill-color"] = c.building; paint["fill-outline-color"] = c.buildingLine
        case id.hasSuffix("_casing"): paint["line-color"] = c.casing
        case id.hasSuffix("_inner"): paint["line-color"] = c.road
        case id.hasPrefix("highway-name"): paint["text-color"] = c.label; paint["text-halo-color"] = "#ffffff"; paint["text-halo-width"] = 1.5
        case id.hasPrefix("water_name"): paint["text-color"] = c.waterLabel
        case id.hasPrefix("label_"): paint["text-color"] = "#4a4d52"
        case id.hasPrefix("highway-shield"), id.hasPrefix("road_shield"): l["layout"] = ["visibility": "none"]
        default: break
        }
        if id == "highway_minor" {
            var casing = l
            casing["id"] = "highway_minor_casing"
            casing["paint"] = ["line-color": c.minorCasing, "line-width": width(1)]
            out.append(casing)
            paint["line-color"] = c.minor; paint["line-opacity"] = 1; paint["line-width"] = width(0.8)
        }
        l["paint"] = paint
        out.append(l)
    }
    style["layers"] = out
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("waze-style.json")
    guard let json = try? JSONSerialization.data(withJSONObject: style) else { return nil }
    try? json.write(to: url)
    return url
}

// MARK: - Images drawn for the map

/// Your-location avatar: 3D low-poly EV (Krea) on a soft grey disc, like Waze's vehicle.
private func carPuck() -> UIImage {
    let car = UIImage(named: "avatar_car")!
    return UIGraphicsImageRenderer(size: .init(width: 70, height: 70)).image { r in
        UIColor(red: 0.45, green: 0.5, blue: 0.58, alpha: 0.28).setFill()
        r.cgContext.fillEllipse(in: CGRect(x: 4, y: 14, width: 62, height: 50))
        car.draw(in: CGRect(x: 10, y: 4, width: 50, height: 50))
    }
}

/// Route-preview location: blue dot with halo (Waze shows this before you start driving).
private func blueDot() -> UIImage {
    UIGraphicsImageRenderer(size: .init(width: 56, height: 56)).image { r in
        let g = r.cgContext
        UIColor(red: 0.45, green: 0.5, blue: 0.58, alpha: 0.25).setFill(); g.fillEllipse(in: CGRect(x: 0, y: 0, width: 56, height: 56))
        g.setShadow(offset: .init(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        UIColor.white.setFill(); g.fillEllipse(in: CGRect(x: 16, y: 16, width: 24, height: 24))
        g.setShadow(offset: .zero, blur: 0, color: nil)
        UIColor(red: 0.1, green: 0.55, blue: 1, alpha: 1).setFill(); g.fillEllipse(in: CGRect(x: 20, y: 20, width: 16, height: 16))
    }
}

/// Waze ETA bubble: purple "12 min / Best" for the chosen route, white "13 min" for alternatives.
private func etaBubble(_ title: String, sub: String?, best: Bool) -> UIImage {
    let tf = UIFont.systemFont(ofSize: 16, weight: .bold), sf = UIFont.systemFont(ofSize: 15, weight: .semibold)
    let fg: UIColor = best ? .white : UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
    let t = NSAttributedString(string: title, attributes: [.font: tf, .foregroundColor: fg])
    let s = sub.map { NSAttributedString(string: $0, attributes: [.font: sf, .foregroundColor: fg]) }
    let w = max(t.size().width, s?.size().width ?? 0) + 20
    let h = t.size().height + (s?.size().height ?? 0) + 12
    return UIGraphicsImageRenderer(size: .init(width: w + 8, height: h + 8)).image { r in
        let rect = CGRect(x: 4, y: 3, width: w, height: h)
        let p = UIBezierPath(roundedRect: rect, cornerRadius: 9)
        r.cgContext.setShadow(offset: .init(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.25).cgColor)
        (best ? UIColor(red: 0.05, green: 0.42, blue: 0.88, alpha: 1) : .white).setFill(); p.fill()
        r.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        if !best { UIColor(white: 0.85, alpha: 1).setStroke(); p.lineWidth = 1; p.stroke() }
        t.draw(at: .init(x: rect.minX + 10, y: rect.minY + 6))
        s?.draw(at: .init(x: rect.minX + 10, y: rect.minY + 6 + t.size().height))
    }
}

/// Waze destination marker: checkered disc on a white pin.
private func flagPin() -> UIImage {
    UIGraphicsImageRenderer(size: .init(width: 44, height: 56)).image { r in
        let g = r.cgContext
        g.setShadow(offset: .init(width: 0, height: 1.5), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        let pin = UIBezierPath()
        pin.addArc(withCenter: .init(x: 22, y: 21), radius: 19, startAngle: .pi * 0.8, endAngle: .pi * 0.2, clockwise: true)
        pin.addLine(to: .init(x: 22, y: 52)); pin.close()
        UIColor.white.setFill(); pin.fill()
        g.setShadow(offset: .zero, blur: 0, color: nil)
        g.saveGState()
        UIBezierPath(ovalIn: CGRect(x: 6, y: 5, width: 32, height: 32)).addClip()
        let cell: CGFloat = 6.4
        for i in 0..<5 { for j in 0..<5 {
            ((i + j) % 2 == 0 ? UIColor(white: 0.1, alpha: 1) : UIColor.white).setFill()
            g.fill(CGRect(x: 6 + CGFloat(i) * cell, y: 5 + CGFloat(j) * cell, width: cell, height: cell))
        } }
        g.restoreGState()
    }
}

struct RouteLabel { let at: CLLocationCoordinate2D; let minutes: Int; let best: Bool }

struct WazeMap: UIViewRepresentable {
    let views: [StationView]
    let user: CLLocationCoordinate2D
    let selectedId: String?
    /// simulated drive: route + start time; the coordinator animates car and camera from these at 60 fps
    let navRoute: Route?
    let navStart: Date?
    let route: [CLLocationCoordinate2D]?
    let alternatives: [[CLLocationCoordinate2D]]
    let labels: [RouteLabel]
    let mode: MapMode
    let recenterTick: Int
    /// bottom inset so the camera centres above the sheet
    let bottomInset: CGFloat
    let onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MLNMapView {
        let m = MLNMapView(frame: .zero, styleURL: wazeStyleURL())
        m.delegate = context.coordinator
        m.logoView.isHidden = true
        m.compassView.isHidden = true
        m.attributionButton.isHidden = true // attribution shown in the menu footer
        m.automaticallyAdjustsContentInset = false
        m.setCenter(user, zoomLevel: 14.4, animated: false)
        m.maximumZoomLevel = 19
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        // wait only for double-tap (zoom); MapLibre's own single tap must not be able to swallow ours
        for g in m.gestureRecognizers ?? [] { if let t = g as? UITapGestureRecognizer, t.numberOfTapsRequired > 1 { tap.require(toFail: t) } }
        tap.delegate = context.coordinator
        m.addGestureRecognizer(tap)
        context.coordinator.map = m
        return m
    }

    func updateUIView(_ m: MLNMapView, context: Context) {
        let c = context.coordinator
        let prev = c.parent
        c.parent = self
        guard c.styleReady else { return }
        c.syncStations()
        c.syncUser()
        c.syncNav()
        if mode == .route, prev.mode != .route, route == nil, let id = selectedId, let v = views.first(where: { $0.id == id }) {
            c.previewZoom(to: v.coordinate)
        } else if prev.route?.count != route?.count || prev.alternatives.count != alternatives.count || prev.mode != mode {
            c.syncRoute()
        }
        if prev.selectedId != selectedId, mode == .browse, let v = views.first(where: { $0.id == selectedId }) {
            m.setContentInset(.init(top: 0, left: 0, bottom: 470, right: 0), animated: true, completionHandler: nil)
            m.setCenter(v.coordinate, zoomLevel: max(m.zoomLevel, 14.8), animated: true)
        }
        if prev.recenterTick != recenterTick {
            m.setContentInset(.init(top: 380, left: 0, bottom: bottomInset, right: 0), animated: false, completionHandler: nil)
            m.setCamera(MLNMapCamera(lookingAtCenter: user, altitude: 2200, pitch: 0, heading: 0), animated: true)
        }
        if mode != .nav && prev.mode == .nav {
            m.setContentInset(.init(top: 380, left: 0, bottom: bottomInset, right: 0), animated: false, completionHandler: nil)
            m.setCamera(MLNMapCamera(lookingAtCenter: user, altitude: 1500, pitch: 0, heading: 0), animated: true)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: WazeMap
        weak var map: MLNMapView?
        var styleReady = false
        private var stationSource: MLNShapeSource?
        private var routeSource: MLNShapeSource?
        private var altSource: MLNShapeSource?
        private var labelSource: MLNShapeSource?
        private var userSource: MLNShapeSource?
        private var userLayer: MLNSymbolStyleLayer?
        private var lastStationsKey = ""
        private var fadeLayers: [MLNStyleLayer] = []   // alternatives + bubbles, faded in after the draw
        private var drawTimer: Timer?
        private var navLink: CADisplayLink?
        private var car3D: Car3DView?
        /// car follows the road quickly, the camera follows the car with a delay (Waze / Google Maps feel)
        private var carBearing = 0.0, camHeading = 0.0
        private var camCenter = CLLocationCoordinate2D()
        private var lastFrame: CFTimeInterval = 0

        init(_ p: WazeMap) { parent = p }

        private func line(_ id: String, _ src: MLNSource, color: UIColor, widths: [Double], below: MLNStyleLayer? = nil, in style: MLNStyle) -> MLNLineStyleLayer {
            let l = MLNLineStyleLayer(identifier: id, source: src)
            l.lineColor = NSExpression(forConstantValue: color)
            l.lineWidth = NSExpression(mglJSONObject: ["interpolate", ["linear"], ["zoom"], 10, widths[0], 16, widths[1], 19, widths[1] * 1.6])
            l.lineCap = NSExpression(forConstantValue: "round"); l.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(l)
            return l
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // 3D low-poly charger markers (Krea); stale feeds reuse the grey one
            let pins: [PinState: String] = [.free: "pin3d_free", .busy: "pin3d_busy", .overstay: "pin3d_overstay", .broken: "pin3d_broken", .stale: "pin3d_broken"]
            for (state, asset) in pins { if let img = UIImage(named: asset) { style.setImage(img, forName: "pin-\(state.rawValue)") } }
            style.setImage(carPuck(), forName: "puck-car")
            style.setImage(blueDot(), forName: "puck-dot")
            style.setImage(flagPin(), forName: "dest-flag")

            let alt = MLNShapeSource(identifier: "alt", shape: nil, options: nil); style.addSource(alt); altSource = alt
            let altC = line("alt-casing", alt, color: UIColor(red: 0.47, green: 0.67, blue: 0.95, alpha: 1), widths: [4, 8], in: style)
            let altL = line("alt-line", alt, color: UIColor(red: 0.71, green: 0.84, blue: 1.0, alpha: 1), widths: [2.5, 5.5], in: style)
            for l in [altC, altL] { l.lineOpacityTransition = MLNTransition(duration: 0.3, delay: 0) }
            fadeLayers += [altC, altL]
            let rs = MLNShapeSource(identifier: "route", shape: nil, options: nil); style.addSource(rs); routeSource = rs
            _ = line("route-casing", rs, color: UIColor(red: 0.05, green: 0.38, blue: 0.82, alpha: 1), widths: [4.5, 9], in: style)
            _ = line("route-line", rs, color: UIColor(red: 0.12, green: 0.56, blue: 1.0, alpha: 1), widths: [3, 6], in: style)

            let ss = MLNShapeSource(identifier: "stations", shape: nil, options: nil)
            style.addSource(ss); stationSource = ss
            let sl = MLNSymbolStyleLayer(identifier: "stations", source: ss)
            sl.iconImageName = NSExpression(forKeyPath: "icon")
            sl.iconAnchor = NSExpression(forConstantValue: "bottom")
            sl.iconAllowsOverlap = NSExpression(forConstantValue: true)
            sl.iconIgnoresPlacement = NSExpression(forConstantValue: true)
            sl.iconScale = NSExpression(mglJSONObject: ["interpolate", ["linear"], ["zoom"],
                                                         9, ["case", ["get", "sel"], 0.55, 0.38],
                                                         13, ["case", ["get", "sel"], 0.95, 0.68],
                                                         16, ["case", ["get", "sel"], 1.25, 0.95]])
            sl.symbolSortKey = NSExpression(forKeyPath: "rank")
            sl.text = NSExpression(mglJSONObject: ["step", ["zoom"], "", 13.8, ["get", "label"]])
            sl.textFontNames = NSExpression(forConstantValue: ["Noto Sans Bold"])
            sl.textFontSize = NSExpression(forConstantValue: 11)
            sl.textOffset = NSExpression(forConstantValue: NSValue(cgVector: .init(dx: 0, dy: 0.3)))
            sl.textAnchor = NSExpression(forConstantValue: "top")
            sl.textOptional = NSExpression(forConstantValue: true)
            sl.textColor = NSExpression(forConstantValue: UIColor(W.text))
            sl.textHaloColor = NSExpression(forConstantValue: UIColor.white)
            sl.textHaloWidth = NSExpression(forConstantValue: 1.6)
            style.addLayer(sl)

            let us = MLNShapeSource(identifier: "user", shape: nil, options: nil)
            style.addSource(us); userSource = us
            let ul = MLNSymbolStyleLayer(identifier: "user", source: us)
            ul.iconImageName = NSExpression(forConstantValue: "puck-car")
            ul.iconAllowsOverlap = NSExpression(forConstantValue: true)
            ul.iconIgnoresPlacement = NSExpression(forConstantValue: true)
            style.addLayer(ul); userLayer = ul

            let ls = MLNShapeSource(identifier: "route-labels", shape: nil, options: nil)
            style.addSource(ls); labelSource = ls
            let ll = MLNSymbolStyleLayer(identifier: "route-labels", source: ls)
            ll.iconImageName = NSExpression(forKeyPath: "icon")
            ll.iconAnchor = NSExpression(forKeyPath: "anchor")
            ll.iconAllowsOverlap = NSExpression(forConstantValue: true)
            ll.iconIgnoresPlacement = NSExpression(forConstantValue: true)
            ll.iconOpacityTransition = MLNTransition(duration: 0.3, delay: 0)
            style.addLayer(ll)
            fadeLayers.append(ll)

            styleReady = true
            if let id = parent.selectedId, let v = parent.views.first(where: { $0.id == id }) {
                mapView.setContentInset(.init(top: 0, left: 0, bottom: 470, right: 0), animated: false, completionHandler: nil)
                mapView.setCenter(v.coordinate, zoomLevel: 14.8, animated: false)
            } else {
                mapView.setContentInset(.init(top: 380, left: 0, bottom: parent.bottomInset, right: 0), animated: false, completionHandler: nil)
                mapView.setCenter(parent.user, zoomLevel: 14.4, animated: false)
            }
            syncStations(); syncUser(); syncRoute()
        }

        func syncStations() {
            let browsing = parent.mode == .browse
            let key = "\(browsing)-\(parent.views.count)-\(parent.selectedId ?? "")-\(parent.views.reduce(0) { $0 &+ $1.free &* 31 &+ $1.overstays })"
            guard key != lastStationsKey, let src = stationSource else { return }
            lastStationsKey = key
            // while previewing / driving a route the destination flag marks the station, so no pins at all
            let shown = browsing ? parent.views : []
            let feats: [MLNPointFeature] = shown.map { v in
                let f = MLNPointFeature()
                f.coordinate = v.coordinate
                let sel = v.id == parent.selectedId
                f.attributes = [
                    "id": v.id, "icon": "pin-\(v.pin.rawValue)", "sel": sel,
                    "label": "\(v.free)/\(v.total)\(v.dc ? " ⚡" : "")",
                    "rank": sel ? 10 : v.pin == .free ? 5 : v.pin == .overstay ? 4 : 1,
                ]
                return f
            }
            src.shape = MLNShapeCollectionFeature(shapes: feats)
        }

        /// Start / stop the 60 fps drive loop.
        func syncNav() {
            let driving = parent.mode == .nav && parent.navRoute != nil && parent.navStart != nil
            if driving, navLink == nil, let r = parent.navRoute {
                map?.setContentInset(.init(top: 300, left: 0, bottom: 0, right: 0), animated: false, completionHandler: nil)
                carBearing = roadBearing(r, at: 0); camHeading = carBearing
                camCenter = r.along(0).0
                lastFrame = 0
                let car = Car3DView(side: 165, pitch: 58)
                map?.addSubview(car)
                car3D = car
                userLayer?.iconOpacity = NSExpression(forConstantValue: 0) // the 3D car replaces the flat puck
                let link = CADisplayLink(target: self, selector: #selector(driveFrame(_:)))
                link.add(to: .main, forMode: .common)
                navLink = link
            } else if !driving, let link = navLink {
                link.invalidate()
                navLink = nil
                car3D?.removeFromSuperview()
                car3D = nil
                userLayer?.iconOpacity = NSExpression(forConstantValue: 1)
            }
        }

        /// One frame: the car sits exactly on the route and turns with the road; the camera trails it in
        /// position (~0.25 s) and heading (~0.9 s), so in a corner you see the car turn before the view swings round.
        @objc private func driveFrame(_ link: CADisplayLink) {
            guard let m = map, let r = parent.navRoute, let start = parent.navStart else { return }
            let d = navDistance(r, start: start, at: .now)
            let pos = r.along(d).0
            let dt = lastFrame == 0 ? 0 : link.timestamp - lastFrame
            lastFrame = link.timestamp
            func ease(_ tau: Double) -> Double { 1 - exp(-dt / tau) }
            func turn(_ from: Double, to: Double, _ k: Double) -> Double {
                var delta = (to - from).truncatingRemainder(dividingBy: 360)
                if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
                return (from + delta * k + 360).truncatingRemainder(dividingBy: 360)
            }
            if d < r.total { carBearing = turn(carBearing, to: roadBearing(r, at: d), ease(0.12)) }
            camHeading = turn(camHeading, to: carBearing, ease(0.9))
            let k = ease(0.25)
            camCenter = .init(latitude: camCenter.latitude + (pos.latitude - camCenter.latitude) * k,
                              longitude: camCenter.longitude + (pos.longitude - camCenter.longitude) * k)

            let f = MLNPointFeature(); f.coordinate = pos
            userSource?.shape = f
            m.setCamera(MLNMapCamera(lookingAtCenter: camCenter, acrossDistance: 420, pitch: 58, heading: camHeading), animated: false)
            if let car = car3D {
                car.center = m.convert(pos, toPointTo: m)
                car.setHeading(carBearing - camHeading) // car's angle on screen (screen-up = camera heading)
            }
        }

        func syncUser() {
            userLayer?.iconImageName = NSExpression(forConstantValue: parent.mode == .route ? "puck-dot" : "puck-car")
            if navLink != nil { return } // the drive loop owns the car while navigating
            let f = MLNPointFeature(); f.coordinate = parent.user
            userSource?.shape = f
        }

        private func setFade(_ on: Bool) {
            for l in fadeLayers {
                if let l = l as? MLNLineStyleLayer { l.lineOpacity = NSExpression(forConstantValue: on ? 1 : 0) }
                if let l = l as? MLNSymbolStyleLayer { l.iconOpacity = NSExpression(forConstantValue: on ? 1 : 0) }
            }
        }

        private func fit(_ coords: [CLLocationCoordinate2D], duration: TimeInterval) {
            guard let m = map, var sw = coords.first else { return }
            var ne = sw
            for p in coords {
                sw.latitude = min(sw.latitude, p.latitude); sw.longitude = min(sw.longitude, p.longitude)
                ne.latitude = max(ne.latitude, p.latitude); ne.longitude = max(ne.longitude, p.longitude)
            }
            m.setContentInset(.zero, animated: false, completionHandler: nil)
            let cam = m.cameraThatFitsCoordinateBounds(MLNCoordinateBounds(sw: sw, ne: ne), edgePadding: .init(top: 190, left: 60, bottom: 330, right: 60))
            cam.pitch = 0; cam.heading = 0
            m.setCamera(cam, withDuration: duration, animationTimingFunction: CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1), completionHandler: nil)
        }

        /// Entering the preview before the route arrives: ease out to show you + the destination.
        func previewZoom(to dest: CLLocationCoordinate2D) {
            drawTimer?.invalidate()
            setFade(false)
            routeSource?.shape = nil; altSource?.shape = nil; labelSource?.shape = nil
            fit([parent.user, dest], duration: 0.8)
        }

        func syncRoute() {
            drawTimer?.invalidate()
            guard let src = routeSource, let m = map, let style = m.style else { return }
            guard let r = parent.route, r.count > 1, parent.mode != .browse else {
                src.shape = nil; altSource?.shape = nil; labelSource?.shape = nil; return
            }
            let preview = parent.mode == .route
            if preview { setFade(false) }   // hide bubbles/alternatives before they get their shapes
            altSource?.shape = preview ? MLNShapeCollectionFeature(shapes: parent.alternatives.map { a in
                var a = a; return MLNPolylineFeature(coordinates: &a, count: UInt(a.count))
            }) : nil

            // ETA bubbles + destination flag
            var feats: [MLNPointFeature] = []
            if preview {
                for (i, l) in parent.labels.enumerated() {
                    let name = "eta-\(i)"
                    style.setImage(etaBubble("\(l.minutes) min", sub: l.best ? "Geriausias" : nil, best: l.best), forName: name)
                    let f = MLNPointFeature(); f.coordinate = l.at; f.attributes = ["icon": name, "anchor": "center"]
                    feats.append(f)
                }
            }
            let dest = MLNPointFeature(); dest.coordinate = r.last!; dest.attributes = ["icon": "dest-flag", "anchor": "bottom"]
            feats.append(dest)
            labelSource?.shape = MLNShapeCollectionFeature(shapes: feats)

            guard preview else {
                var all = r
                src.shape = MLNPolylineFeature(coordinates: &all, count: UInt(all.count))
                setFade(true)
                return
            }

            // camera settles on the whole route while the line draws itself from you to the station
            fit(([r] + parent.alternatives).flatMap { $0 }, duration: 0.7)
            setFade(false)
            drawLine(r, into: src, duration: 0.7, delay: 0.12)
        }

        private func drawLine(_ r: [CLLocationCoordinate2D], into src: MLNShapeSource, duration: TimeInterval, delay: TimeInterval) {
            var cum = [0.0]
            for i in 1..<r.count { cum.append(cum[i - 1] + hypot(r[i].latitude - r[i - 1].latitude, r[i].longitude - r[i - 1].longitude)) }
            let total = max(cum.last ?? 0, 1e-12)
            src.shape = nil
            let start = Date().addingTimeInterval(delay)
            drawTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] t in
                let el = Date().timeIntervalSince(start)
                guard el >= 0 else { return }
                let x = min(1, el / duration)
                let p = 1 - pow(1 - x, 3) // ease-out cubic
                let target = p * total
                var i = cum.firstIndex(where: { $0 >= target }) ?? r.count - 1
                i = max(1, i)
                let seg = max(cum[i] - cum[i - 1], 1e-12), f = (target - cum[i - 1]) / seg
                var pts = Array(r[0..<i])
                pts.append(.init(latitude: r[i - 1].latitude + (r[i].latitude - r[i - 1].latitude) * f,
                                 longitude: r[i - 1].longitude + (r[i].longitude - r[i - 1].longitude) * f))
                src.shape = MLNPolylineFeature(coordinates: &pts, count: UInt(pts.count))
                if x >= 1 {
                    t.invalidate()
                    var all = r
                    src.shape = MLNPolylineFeature(coordinates: &all, count: UInt(all.count))
                    self?.setFade(true)
                }
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        /// Pin icon scale at a zoom level – mirrors the `iconScale` interpolation of the stations layer.
        private func pinScale(_ zoom: Double, selected: Bool) -> CGFloat {
            let stops: [(Double, Double)] = selected ? [(9, 0.55), (13, 0.95), (16, 1.25)] : [(9, 0.38), (13, 0.68), (16, 0.95)]
            if zoom <= stops[0].0 { return stops[0].1 }
            for (a, b) in zip(stops, stops.dropFirst()) where zoom <= b.0 {
                return a.1 + (b.1 - a.1) * (zoom - a.0) / (b.0 - a.0)
            }
            return stops[stops.count - 1].1
        }

        /// Hit-test the pins ourselves from their on-screen size (27×50 pt at scale 1, anchored at the bottom),
        /// with a finger-sized margin; the nearest pin to the tap wins.
        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard let m = map, parent.mode == .browse else { return }
            let pt = g.location(in: m)
            let b = m.visibleCoordinateBounds
            var best: (id: String, dist: CGFloat)?
            for v in parent.views {
                let c = v.coordinate
                guard c.latitude >= b.sw.latitude, c.latitude <= b.ne.latitude,
                      c.longitude >= b.sw.longitude, c.longitude <= b.ne.longitude else { continue }
                let a = m.convert(c, toPointTo: m)
                let k = pinScale(m.zoomLevel, selected: v.id == parent.selectedId)
                let w = max(44, 27 * k + 16), h = max(44, 50 * k + 12)
                let hit = CGRect(x: a.x - w / 2, y: a.y - h + 6, width: w, height: h)
                guard hit.contains(pt) else { continue }
                let d = hypot(pt.x - a.x, pt.y - (a.y - 25 * k))
                if best == nil || d < best!.dist { best = (v.id, d) }
            }
            // hand over on the next run-loop turn: changing app state from inside the map's gesture/update
            // pass made SwiftUI drop the follow-up screen change (pin selected, sheet never shown)
            if let id = best?.id { DispatchQueue.main.async { self.parent.onSelect(id) } }
        }
    }
}
