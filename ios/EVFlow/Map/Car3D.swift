import SceneKit
import UIKit

/// Low-poly 3D car drawn live over the map while navigating. Its camera is tilted like the map's,
/// so turning the car shows real perspective instead of a rotated picture.
final class Car3DView: SCNView {
    private let car = SCNNode()
    private let camNode = SCNNode()

    init(side: CGFloat, pitch: Double) {
        super.init(frame: CGRect(x: 0, y: 0, width: side, height: side), options: nil)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        antialiasingMode = .multisampling4X
        let scene = SCNScene()
        self.scene = scene
        scene.rootNode.addChildNode(car)
        scene.lightingEnvironment.contents = Self.skyImage
        scene.lightingEnvironment.intensity = 1.3
        buildCar()

        let cam = SCNCamera()
        cam.fieldOfView = 26
        cam.zNear = 0.1; cam.zFar = 100
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)
        setPitch(pitch)

        let ambient = SCNNode(); ambient.light = SCNLight()
        ambient.light?.type = .ambient; ambient.light?.intensity = 850
        scene.rootNode.addChildNode(ambient)
        let sun = SCNNode(); sun.light = SCNLight()
        sun.light?.type = .directional; sun.light?.intensity = 900
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(sun)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Map pitch in degrees (0 = straight down).
    func setPitch(_ deg: Double) {
        let p = Float(deg * .pi / 180), dist: Float = 16
        camNode.position = SCNVector3(0, dist * cos(p), dist * sin(p))
        camNode.look(at: SCNVector3(0, 0.5, 0))
    }

    /// Car angle on screen in degrees, clockwise from screen-up.
    func setHeading(_ deg: Double) {
        car.eulerAngles.y = Float(-deg * .pi / 180)
    }

    // MARK: model (metres; the car faces -z, i.e. up the screen)

    /// Waze-style toy car built from rounded shapes: chunky body, bubble cabin with glossy glass, fat tyres.
    private func paint(_ c: UIColor, rough: CGFloat = 0.35, metal: CGFloat = 0.05, glow: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = glow ? .constant : .physicallyBased
        m.diffuse.contents = c
        m.roughness.contents = rough
        m.metalness.contents = metal
        return m
    }

    private func part(_ g: SCNGeometry, _ m: SCNMaterial, _ p: SCNVector3, rotZ: Float = 0) {
        g.materials = [m]
        let n = SCNNode(geometry: g); n.position = p; n.eulerAngles.z = rotZ
        car.addChildNode(n)
    }

    private func buildCar() {
        // soft shadow on the road
        let shadow = SCNPlane(width: 2.6, height: 4.8)
        let sm = SCNMaterial(); sm.lightingModel = .constant; sm.diffuse.contents = Self.shadowImage; sm.writesToDepthBuffer = false
        shadow.materials = [sm]
        let sn = SCNNode(geometry: shadow); sn.eulerAngles.x = -.pi / 2; sn.position = SCNVector3(0, 0.01, 0)
        car.addChildNode(sn)

        let blue = paint(UIColor(red: 0.13, green: 0.56, blue: 1.0, alpha: 1), rough: 0.28)
        let glass = paint(UIColor(red: 0.10, green: 0.16, blue: 0.28, alpha: 1), rough: 0.08, metal: 0.3)
        let tyre = paint(UIColor(white: 0.12, alpha: 1), rough: 0.8)
        let hub = paint(UIColor(white: 0.85, alpha: 1), rough: 0.3, metal: 0.4)
        let trim = paint(UIColor(red: 0.08, green: 0.36, blue: 0.75, alpha: 1), rough: 0.5)

        // body + bubble cabin + roof cap (windows read as a dark band)
        part(SCNBox(width: 1.9, height: 0.72, length: 3.8, chamferRadius: 0.34), blue, SCNVector3(0, 0.66, 0))
        part(SCNBox(width: 1.62, height: 0.74, length: 2.1, chamferRadius: 0.36), glass, SCNVector3(0, 1.16, 0.28))
        part(SCNBox(width: 1.5, height: 0.2, length: 1.62, chamferRadius: 0.1), blue, SCNVector3(0, 1.5, 0.32))
        // bumpers
        part(SCNBox(width: 1.84, height: 0.26, length: 0.3, chamferRadius: 0.12), trim, SCNVector3(0, 0.42, 1.86))
        part(SCNBox(width: 1.84, height: 0.26, length: 0.3, chamferRadius: 0.12), trim, SCNVector3(0, 0.42, -1.86))
        // fat wheels with hubcaps
        for x: Float in [-0.92, 0.92] { for z: Float in [-1.2, 1.25] {
            part(SCNCylinder(radius: 0.4, height: 0.36), tyre, SCNVector3(x, 0.4, z), rotZ: .pi / 2)
            part(SCNCylinder(radius: 0.19, height: 0.38), hub, SCNVector3(x * 1.01, 0.4, z), rotZ: .pi / 2)
        } }
        // lights: red tail lights (seen from behind), white headlights
        let tail = paint(UIColor(red: 1, green: 0.22, blue: 0.25, alpha: 1), glow: true)
        let head = paint(UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1), glow: true)
        for x: Float in [-0.62, 0.62] {
            part(SCNBox(width: 0.42, height: 0.16, length: 0.08, chamferRadius: 0.06), tail, SCNVector3(x, 0.78, 1.88))
            part(SCNBox(width: 0.36, height: 0.16, length: 0.08, chamferRadius: 0.06), head, SCNVector3(x, 0.74, -1.88))
        }
    }

    /// Soft sky → ground gradient so the glossy paint gets a gentle reflection.
    private static let skyImage: UIImage = UIGraphicsImageRenderer(size: .init(width: 64, height: 256)).image { r in
        let colors = [UIColor.white.cgColor, UIColor(white: 0.82, alpha: 1).cgColor, UIColor(white: 0.45, alpha: 1).cgColor] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
        r.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
    }

    private static let shadowImage: UIImage = UIGraphicsImageRenderer(size: .init(width: 64, height: 120)).image { r in
        let colors = [UIColor(white: 0, alpha: 0.32).cgColor, UIColor(white: 0, alpha: 0).cgColor] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        r.cgContext.scaleBy(x: 1, y: 120.0 / 64)
        r.cgContext.drawRadialGradient(g, startCenter: .init(x: 32, y: 32), startRadius: 0, endCenter: .init(x: 32, y: 32), endRadius: 32, options: [])
    }
}
