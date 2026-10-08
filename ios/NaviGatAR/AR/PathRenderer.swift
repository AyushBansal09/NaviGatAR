import ARKit
import CoreText
import RealityKit
import UIKit

/// Draws routes in AR. Everything lives under `routeFrame`, whose transform is
/// the alignment between the route's coordinate frame (a QR sign) and the AR
/// world, so re-aligning only moves one entity.
final class PathRenderer {
    /// How far below the recorded phone height the path is drawn (≈ waist height).
    static let pathDrop: Float = 0.45

    private let worldAnchor = AnchorEntity(world: Vec3(0, 0, 0))
    private let routeFrame = Entity()
    private var markers: [(entity: Entity, arc: Float)] = []
    private lazy var breadcrumbMesh = MeshResource.generateSphere(radius: 0.03)
    private lazy var breadcrumbMaterial = UnlitMaterial(color: UIColor.systemOrange)

    func attach(to arView: ARView) {
        worldAnchor.addChild(routeFrame)
        routeFrame.isEnabled = false
        arView.scene.addAnchor(worldAnchor)
    }

    func setAlignment(_ pose: Pose) {
        routeFrame.position = pose.position
        routeFrame.orientation = simd_quatf(angle: pose.yaw, axis: Vec3(0, 1, 0))
    }

    func setVisible(_ visible: Bool) { routeFrame.isEnabled = visible }

    func clear() {
        for child in Array(routeFrame.children) { child.removeFromParent() }
        markers.removeAll()
    }

    // MARK: Navigation

    func showPath(points: [Vec3], notes: [RouteNote], signs: [Pose], destinationLabel: String?,
                  settings: GuidanceSettings) {
        clear()
        let index = PolylineIndex(points: points)
        let color = settings.highContrast ? UIColor(red: 1, green: 0.92, blue: 0, alpha: 1) : settings.color.uiColor
        let scale: Float = settings.highContrast ? 1.4 : 1
        let material: RealityKit.Material
        if settings.highContrast {
            material = UnlitMaterial(color: color)
        } else {
            material = SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)
        }

        let spacing: Float
        switch settings.style {
        case .spheres: spacing = 0.6
        case .dots: spacing = 0.35
        case .arrows: spacing = 0.7
        }
        let sphereMesh = MeshResource.generateSphere(radius: (settings.style == .dots ? 0.035 : 0.06) * scale)

        for sample in index.resample(spacing: spacing) where sample.arc < index.total - 0.4 {
            let entity: Entity
            if settings.style == .arrows {
                entity = makeChevron(material: material, scale: scale)
                let back = -sample.direction
                entity.orientation = simd_quatf(angle: atan2(back.x, back.z), axis: Vec3(0, 1, 0))
            } else {
                entity = ModelEntity(mesh: sphereMesh, materials: [material])
            }
            entity.position = sample.position + Vec3(0, -Self.pathDrop, 0)
            routeFrame.addChild(entity)
            markers.append((entity, sample.arc))
        }

        for note in notes {
            let label = makeLabel(note.text, textColor: .white,
                                  plateColor: UIColor(red: 0.30, green: 0.20, blue: 0.60, alpha: 1))
            label.position = note.position + Vec3(0, 0.05, 0)
            routeFrame.addChild(label)
            markers.append((label, index.project(note.position)?.arc ?? 0))
        }

        for sign in signs { routeFrame.addChild(makeSignOutline(at: sign)) }

        if let end = points.last {
            let pinMaterial = UnlitMaterial(color: UIColor.systemPink)
            let pole = ModelEntity(mesh: .generateBox(width: 0.03, height: 0.9, depth: 0.03), materials: [pinMaterial])
            pole.position = end + Vec3(0, -0.6, 0)
            let ball = ModelEntity(mesh: .generateSphere(radius: 0.12), materials: [pinMaterial])
            ball.position = end + Vec3(0, -0.15, 0)
            routeFrame.addChild(pole)
            routeFrame.addChild(ball)
            if let destinationLabel {
                let label = makeLabel(destinationLabel, textColor: .white, plateColor: UIColor.systemPink)
                label.position = end + Vec3(0, 0.15, 0)
                routeFrame.addChild(label)
            }
        }
        updateVisibility(progress: 0)
    }

    /// Shows only the part of the path around the visitor to keep the view calm.
    func updateVisibility(progress arc: Float) {
        for marker in markers {
            marker.entity.isEnabled = marker.arc >= arc - 1.5 && marker.arc <= arc + 25
        }
    }

    // MARK: Recording

    func addBreadcrumb(_ localPoint: Vec3) {
        let entity = ModelEntity(mesh: breadcrumbMesh, materials: [breadcrumbMaterial])
        entity.position = localPoint + Vec3(0, -Self.pathDrop, 0)
        routeFrame.addChild(entity)
    }

    func addNoteLabel(_ text: String, at localPoint: Vec3) {
        let label = makeLabel(text, textColor: .white, plateColor: UIColor(red: 0.30, green: 0.20, blue: 0.60, alpha: 1))
        label.position = localPoint + Vec3(0, 0.05, 0)
        routeFrame.addChild(label)
    }

    func addSignOutline(_ pose: Pose) { routeFrame.addChild(makeSignOutline(at: pose)) }

    // MARK: Building blocks

    /// A floating text label that always turns to face the viewer.
    private func makeLabel(_ text: String, textColor: UIColor, plateColor: UIColor) -> Entity {
        let container = Entity()
        let mesh = MeshResource.generateText(text,
                                             extrusionDepth: 0.002,
                                             font: .systemFont(ofSize: 0.07, weight: .bold),
                                             containerFrame: CGRect(x: 0, y: 0, width: 0.8, height: 0.6),
                                             alignment: .center,
                                             lineBreakMode: .byWordWrapping)
        let bounds = mesh.bounds
        let textEntity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: textColor)])
        textEntity.position = Vec3(-bounds.center.x, -bounds.center.y, 0.004)
        let plate = ModelEntity(mesh: .generatePlane(width: bounds.extents.x + 0.08,
                                                     height: bounds.extents.y + 0.05,
                                                     cornerRadius: 0.025),
                                materials: [UnlitMaterial(color: plateColor)])
        container.addChild(plate)
        container.addChild(textEntity)
        container.components.set(BillboardComponent())
        return container
    }

    /// A ">"-shaped arrow made of two bars, pointing along the entity's -Z axis.
    private func makeChevron(material: RealityKit.Material, scale: Float) -> Entity {
        let parent = Entity()
        let tip = Vec3(0, 0, -0.07) * scale
        for side: Float in [-1, 1] {
            let back = Vec3(0.09 * side, 0, 0.05) * scale
            let along = back - tip
            let bar = ModelEntity(mesh: .generateBox(width: 0.035 * scale, height: 0.015 * scale,
                                                     depth: Geo.length(along) + 0.02 * scale),
                                  materials: [material])
            bar.position = (tip + back) / 2
            bar.orientation = simd_quatf(angle: atan2(along.x, along.z), axis: Vec3(0, 1, 0))
            parent.addChild(bar)
        }
        return parent
    }

    /// A green square drawn around where a QR sign should be, so people can
    /// see at a glance that the path is aligned.
    private func makeSignOutline(at pose: Pose) -> Entity {
        let parent = Entity()
        parent.position = pose.position
        parent.orientation = simd_quatf(angle: pose.yaw, axis: Vec3(0, 1, 0))
        let material = UnlitMaterial(color: UIColor.systemGreen)
        let half: Float = 0.12, thickness: Float = 0.012
        let bars: [(Vec3, Float, Float)] = [
            (Vec3(0, half, 0.01), half * 2 + thickness, thickness),
            (Vec3(0, -half, 0.01), half * 2 + thickness, thickness),
            (Vec3(half, 0, 0.01), thickness, half * 2),
            (Vec3(-half, 0, 0.01), thickness, half * 2),
        ]
        for (position, width, height) in bars {
            let bar = ModelEntity(mesh: .generateBox(width: width, height: height, depth: 0.004), materials: [material])
            bar.position = position
            parent.addChild(bar)
        }
        return parent
    }
}
