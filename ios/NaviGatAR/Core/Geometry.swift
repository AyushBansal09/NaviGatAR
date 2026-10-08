import Foundation

/// A point or direction in an AR coordinate space (metres, Y is up).
typealias Vec3 = SIMD3<Float>

/// Small vector helpers. Kept in a namespace so they never clash with
/// framework extensions (simd, RealityKit, …) when compiled into the app.
enum Geo {
    static func dot(_ a: Vec3, _ b: Vec3) -> Float { (a * b).sum() }

    static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        Vec3(a.y * b.z - a.z * b.y,
             a.z * b.x - a.x * b.z,
             a.x * b.y - a.y * b.x)
    }

    static func length(_ v: Vec3) -> Float { dot(v, v).squareRoot() }

    static func normalize(_ v: Vec3) -> Vec3 {
        let l = length(v)
        return l > 1e-6 ? v / l : v
    }

    static func distance(_ a: Vec3, _ b: Vec3) -> Float { length(a - b) }

    /// The vector with its vertical component removed.
    static func flat(_ v: Vec3) -> Vec3 { Vec3(v.x, 0, v.z) }

    /// Distance measured on the floor plane, ignoring height.
    static func flatDistance(_ a: Vec3, _ b: Vec3) -> Float { length(flat(a - b)) }

    /// Wraps an angle into (-pi, pi].
    static func wrapAngle(_ a: Float) -> Float {
        var r = a.truncatingRemainder(dividingBy: 2 * .pi)
        if r > .pi { r -= 2 * .pi }
        if r <= -.pi { r += 2 * .pi }
        return r
    }

    /// Signed turn angle in degrees between two floor directions.
    /// Positive values are turns to the right, negative to the left
    /// (for a viewer whose "up" is +Y).
    static func signedTurnDegrees(from a: Vec3, to b: Vec3) -> Float {
        let fa = normalize(flat(a)), fb = normalize(flat(b))
        let cosine = max(-1, min(1, dot(fa, fb)))
        let degrees = acos(cosine) * 180 / .pi
        return cross(fa, fb).y < 0 ? degrees : -degrees
    }

    /// Total length of a polyline measured on the floor plane.
    static func flatLength(_ points: [Vec3]) -> Float {
        guard points.count > 1 else { return 0 }
        var total: Float = 0
        for i in 1..<points.count { total += flatDistance(points[i - 1], points[i]) }
        return total
    }
}

/// A position plus a heading (rotation about the vertical axis).
///
/// ARKit keeps the world Y axis aligned with gravity, so the only rotation we
/// need to describe a QR anchor or a route frame is a yaw.
struct Pose: Codable, Hashable {
    var position: Vec3
    var yaw: Float

    static let identity = Pose(position: .zero, yaw: 0)

    /// Rotates a vector by `yaw` about +Y (right-handed).
    func rotate(_ v: Vec3) -> Vec3 {
        let c = cos(yaw), s = sin(yaw)
        return Vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z)
    }

    /// Maps a point from this pose's local frame into the parent frame.
    func apply(_ p: Vec3) -> Vec3 { rotate(p) + position }

    func inverse() -> Pose {
        let back = Pose(position: .zero, yaw: -yaw)
        return Pose(position: -back.rotate(position), yaw: -yaw)
    }

    /// `a * b` expresses `b` (given in `a`'s frame) in `a`'s parent frame.
    static func * (a: Pose, b: Pose) -> Pose {
        Pose(position: a.apply(b.position), yaw: Geo.wrapAngle(a.yaw + b.yaw))
    }

    /// The local +Z axis expressed in the parent frame.
    var zAxis: Vec3 { rotate(Vec3(0, 0, 1)) }

    /// A pose whose local +Z axis points along the floor direction `facing`.
    static func facing(_ direction: Vec3, at position: Vec3) -> Pose {
        let d = Geo.flat(direction)
        return Pose(position: position, yaw: atan2(d.x, d.z))
    }

    /// Best guess of a sign's pose when only the camera is known: the person is
    /// assumed to stand ~0.6 m in front of the sign, looking at it.
    static func estimatedAnchor(cameraPosition: Vec3, cameraForward: Vec3) -> Pose {
        var forward = Geo.normalize(Geo.flat(cameraForward))
        if Geo.length(forward) < 0.5 { forward = Vec3(0, 0, -1) }
        let position = cameraPosition + forward * 0.6
        return Pose.facing(-forward, at: position)
    }

    /// Circular-mean average of several poses.
    static func average(_ poses: [Pose]) -> Pose? {
        guard !poses.isEmpty else { return nil }
        var p = Vec3.zero
        var s: Float = 0, c: Float = 0
        for pose in poses {
            p += pose.position
            s += sin(pose.yaw)
            c += cos(pose.yaw)
        }
        return Pose(position: p / Float(poses.count), yaw: atan2(s, c))
    }
}
