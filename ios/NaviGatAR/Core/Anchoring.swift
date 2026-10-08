import Foundation

enum AnchorQuality: String, Hashable {
    /// Position and heading measured from the sign on the wall.
    case precise
    /// Estimated from where the phone is; good enough to get going.
    case approximate
}

/// Turns raycast results for a detected QR code into a sign pose.
///
/// The sign frame is: origin at the code's centre, +Z pointing out of the
/// wall toward the person scanning it, +Y up.
enum QRAnchorEstimator {
    struct Estimate: Equatable {
        var pose: Pose
        var quality: AnchorQuality
    }

    /// - Parameters:
    ///   - cornerHits: world positions of the code's four corners (nil = raycast missed).
    ///   - centerHit: world position of the code's centre.
    ///   - centerNormal: surface normal reported for the centre hit.
    static func estimate(cornerHits: [Vec3?], centerHit: Vec3?, centerNormal: Vec3?,
                         cameraPosition: Vec3, cameraForward: Vec3) -> Estimate {
        let fallback = Estimate(pose: .estimatedAnchor(cameraPosition: cameraPosition, cameraForward: cameraForward),
                                quality: .approximate)
        let corners = cornerHits.compactMap { $0 }

        let position: Vec3
        if corners.count == 4 {
            position = corners.reduce(.zero, +) / 4
        } else if let centerHit {
            position = centerHit
        } else {
            return fallback
        }

        // Reject hits that are clearly wrong (behind the camera or far away).
        let range = Geo.distance(position, cameraPosition)
        guard range > 0.1, range < 6 else { return fallback }

        var normal: Vec3?
        if corners.count >= 3 {
            let candidates = [Geo.cross(corners[1] - corners[0], corners[2] - corners[0]),
                              corners.count == 4 ? Geo.cross(corners[3] - corners[1], corners[2] - corners[1]) : .zero]
            normal = candidates.first { Geo.length($0) > 1e-5 }.map(Geo.normalize)
        }
        if normal == nil, let centerNormal, Geo.length(centerNormal) > 1e-3 { normal = Geo.normalize(centerNormal) }

        if var n = normal {
            if Geo.dot(n, cameraPosition - position) < 0 { n = -n }
            let horizontal = Geo.flat(n)
            // A mostly-horizontal normal means the code is on a wall: use it.
            if Geo.length(horizontal) > 0.5 {
                return Estimate(pose: .facing(horizontal, at: position), quality: .precise)
            }
        }
        // Code lying flat (desk, floor) or unknown orientation: heading from the camera.
        let towardViewer = -Geo.flat(cameraForward)
        guard Geo.length(towardViewer) > 1e-3 else { return fallback }
        return Estimate(pose: .facing(towardViewer, at: position), quality: .approximate)
    }
}

/// Averages a few consecutive detections of the same code before reporting
/// it, which removes most of the jitter from single raycasts.
struct AnchorSampleAccumulator {
    var requiredSamples = 3
    var window: TimeInterval = 2.0
    var maxSpread: Float = 0.2

    private var samples: [String: [(time: TimeInterval, estimate: QRAnchorEstimator.Estimate)]] = [:]

    mutating func add(payload: String, estimate: QRAnchorEstimator.Estimate, time: TimeInterval) -> QRAnchorEstimator.Estimate? {
        var list = (samples[payload] ?? []).filter { time - $0.time <= window }
        list.append((time, estimate))
        samples[payload] = list
        guard list.count >= requiredSamples,
              let mean = Pose.average(list.map { $0.estimate.pose })
        else { return nil }

        let spread = list.map { Geo.distance($0.estimate.pose.position, mean.position) }.max() ?? 0
        guard spread <= maxSpread else {
            samples[payload] = Array(list.suffix(requiredSamples - 1))
            return nil
        }
        samples[payload] = []
        let precise = list.allSatisfy { $0.estimate.quality == .precise }
        return QRAnchorEstimator.Estimate(pose: mean, quality: precise ? .precise : .approximate)
    }

    mutating func reset() { samples.removeAll() }
}

/// Builds a walk segment from camera positions while a manager walks a route.
struct RouteRecorder {
    /// World pose of the start sign.
    let startAnchor: Pose
    private let toLocal: Pose
    private(set) var points: [Vec3] = []
    private(set) var notes: [RouteNote] = []
    var minSpacing: Float = 0.25

    init(startAnchor: Pose) {
        self.startAnchor = startAnchor
        self.toLocal = startAnchor.inverse()
    }

    var length: Float { Geo.flatLength(points) }

    /// Adds a camera position (world space). Returns the stored local point if it was kept.
    @discardableResult
    mutating func add(cameraPosition: Vec3) -> Vec3? {
        guard cameraPosition.x.isFinite, cameraPosition.y.isFinite, cameraPosition.z.isFinite else { return nil }
        let local = toLocal.apply(cameraPosition)
        if let last = points.last, Geo.flatDistance(last, local) < minSpacing { return nil }
        points.append(local)
        return local
    }

    mutating func addNote(_ text: String, cameraPosition: Vec3) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.append(RouteNote(position: toLocal.apply(cameraPosition), text: trimmed))
    }

    mutating func removeLastNote() { _ = notes.popLast() }

    func makeSegment(from: UUID, to: UUID, endAnchor: Pose, finalCameraPosition: Vec3?,
                     stepFree: Bool, bidirectional: Bool) -> Segment {
        var points = self.points
        if let finalCameraPosition {
            let local = toLocal.apply(finalCameraPosition)
            if points.last.map({ Geo.flatDistance($0, local) > 0.05 }) ?? true { points.append(local) }
        }
        return Segment(fromID: from, toID: to, kind: .walk, points: points,
                       endPose: toLocal * endAnchor, notes: notes,
                       stepFree: stepFree, bidirectional: bidirectional)
    }
}
