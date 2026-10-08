import Foundation

/// Arc-length index over a polyline (measured on the floor plane).
struct PolylineIndex {
    let points: [Vec3]
    let arcs: [Float]

    init(points: [Vec3]) {
        self.points = points
        var arcs: [Float] = []
        var total: Float = 0
        for (i, p) in points.enumerated() {
            if i > 0 { total += Geo.flatDistance(points[i - 1], p) }
            arcs.append(total)
        }
        self.arcs = arcs
    }

    var total: Float { arcs.last ?? 0 }

    struct Projection: Equatable {
        var arc: Float
        /// Horizontal distance from the path.
        var distance: Float
        var point: Vec3
    }

    /// Closest point on the path. When `hint` (the previous arc position) is
    /// given, nearby parts of the path win so routes that double back don't
    /// make progress jump.
    func project(_ p: Vec3, hint: Float? = nil) -> Projection? {
        guard let first = points.first else { return nil }
        guard points.count > 1 else {
            return Projection(arc: 0, distance: Geo.flatDistance(first, p), point: first)
        }
        if let hint {
            let local = bestProjection(of: p, arcRange: (hint - 4)...(hint + 12))
            if let local, local.distance <= 3 { return local }
        }
        return bestProjection(of: p, arcRange: nil)
    }

    private func bestProjection(of p: Vec3, arcRange: ClosedRange<Float>?) -> Projection? {
        var best: Projection?
        for i in 1..<points.count {
            if let range = arcRange, arcs[i] < range.lowerBound || arcs[i - 1] > range.upperBound { continue }
            let a = points[i - 1], b = points[i]
            let ab = Geo.flat(b - a)
            let lengthSquared = Geo.dot(ab, ab)
            var t: Float = 0
            if lengthSquared > 1e-6 { t = max(0, min(1, Geo.dot(Geo.flat(p - a), ab) / lengthSquared)) }
            let q = a + (b - a) * t
            let d = Geo.flatDistance(p, q)
            if best == nil || d < best!.distance {
                best = Projection(arc: arcs[i - 1] + (arcs[i] - arcs[i - 1]) * t, distance: d, point: q)
            }
        }
        return best
    }

    func point(atArc s: Float) -> Vec3 {
        guard let first = points.first else { return .zero }
        if s <= 0 || points.count == 1 { return first }
        for i in 1..<points.count where arcs[i] >= s {
            let span = arcs[i] - arcs[i - 1]
            let t = span > 1e-6 ? (s - arcs[i - 1]) / span : 0
            return points[i - 1] + (points[i] - points[i - 1]) * t
        }
        return points[points.count - 1]
    }

    func direction(atArc s: Float) -> Vec3 {
        guard points.count > 1 else { return Vec3(0, 0, -1) }
        let a = point(atArc: max(0, s - 0.3)), b = point(atArc: min(total, s + 0.3))
        let d = Geo.normalize(Geo.flat(b - a))
        return Geo.length(d) > 0.5 ? d : Geo.normalize(Geo.flat(points[points.count - 1] - points[0]))
    }

    struct Sample: Hashable {
        var position: Vec3
        var arc: Float
        var direction: Vec3
    }

    /// Evenly spaced samples along the path (used for the AR "dots").
    func resample(spacing: Float) -> [Sample] {
        guard total > 0, spacing > 0 else { return [] }
        var result: [Sample] = []
        var s: Float = 0
        while s <= total {
            result.append(Sample(position: point(atArc: s), arc: s, direction: direction(atArc: s)))
            s += spacing
        }
        return result
    }

    /// Ramer–Douglas–Peucker simplification; returns kept point indices.
    func simplifiedIndices(tolerance: Float) -> [Int] {
        guard points.count > 2 else { return Array(points.indices) }
        var keep = Array(repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack = [(0, points.count - 1)]
        while let range = stack.popLast() {
            let (start, end) = range
            guard end > start + 1 else { continue }
            var maxDistance: Float = 0
            var index = start
            for i in (start + 1)..<end {
                let d = Self.flatDistance(points[i], toSegment: points[start], points[end])
                if d > maxDistance { maxDistance = d; index = i }
            }
            if maxDistance > tolerance {
                keep[index] = true
                stack.append((start, index))
                stack.append((index, end))
            }
        }
        return keep.indices.filter { keep[$0] }
    }

    static func flatDistance(_ p: Vec3, toSegment a: Vec3, _ b: Vec3) -> Float {
        let ab = Geo.flat(b - a)
        let lengthSquared = Geo.dot(ab, ab)
        guard lengthSquared > 1e-6 else { return Geo.flatDistance(p, a) }
        let t = max(0, min(1, Geo.dot(Geo.flat(p - a), ab) / lengthSquared))
        return Geo.flatDistance(p, a + (b - a) * t)
    }
}

struct NavStep: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case start, slightLeft, slightRight, left, right, uTurn, note, connector, arrive
    }

    var id: Int
    var kind: Kind
    var text: String
    /// Position along the leg (metres from the leg start).
    var arc: Float

    var symbol: String {
        switch kind {
        case .start: return "arrow.up"
        case .slightLeft: return "arrow.up.left"
        case .slightRight: return "arrow.up.right"
        case .left: return "arrow.turn.up.left"
        case .right: return "arrow.turn.up.right"
        case .uTurn: return "arrow.uturn.down"
        case .note: return "exclamationmark.bubble"
        case .connector: return "arrow.up.arrow.down.square"
        case .arrive: return "flag.checkered"
        }
    }
}

enum DirectionsBuilder {
    /// Turn-by-turn steps for a leg.
    /// - Parameter finalText: e.g. "Arrive at Room 360" or a connector instruction.
    static func steps(points: [Vec3], notes: [RouteNote], finalText: String, finalIsConnector: Bool) -> [NavStep] {
        let index = PolylineIndex(points: points)
        var raw: [(NavStep.Kind, String, Float)] = []

        if index.total > 0.5 {
            raw.append((.start, "Follow the path", 0))
            let kept = index.simplifiedIndices(tolerance: 0.6)
            if kept.count > 2 {
                for k in 1..<(kept.count - 1) {
                    let previous = points[kept[k - 1]], vertex = points[kept[k]], next = points[kept[k + 1]]
                    // Very short wiggles are noise from the person recording.
                    if Geo.flatDistance(previous, vertex) < 0.8 || Geo.flatDistance(vertex, next) < 0.8 { continue }
                    let angle = Geo.signedTurnDegrees(from: vertex - previous, to: next - vertex)
                    if let (kind, text) = classify(angle) {
                        raw.append((kind, text, index.arcs[kept[k]]))
                    }
                }
            }
        }

        for note in notes {
            let arc = index.project(note.position)?.arc ?? 0
            raw.append((.note, note.text, arc))
        }

        raw.sort { $0.2 < $1.2 }
        raw.append((finalIsConnector ? .connector : .arrive, finalText, index.total))
        return raw.enumerated().map { NavStep(id: $0.offset, kind: $0.element.0, text: $0.element.1, arc: $0.element.2) }
    }

    static func classify(_ degrees: Float) -> (NavStep.Kind, String)? {
        let magnitude = abs(degrees)
        let right = degrees > 0
        switch magnitude {
        case ..<25: return nil
        case ..<60: return right ? (.slightRight, "Bear right") : (.slightLeft, "Bear left")
        case ..<140: return right ? (.right, "Turn right") : (.left, "Turn left")
        default: return (.uTurn, "Turn around")
        }
    }
}

/// Follows the visitor's progress along one leg.
struct LegTracker {
    let index: PolylineIndex
    let steps: [NavStep]
    private(set) var arc: Float = 0
    private(set) var lateral: Float = 0

    /// Distance (m) from the end that counts as "arrived".
    var arrivalRadius: Float = 1.2
    var offRouteDistance: Float = 3.0

    init(points: [Vec3], steps: [NavStep]) {
        self.index = PolylineIndex(points: points)
        self.steps = steps
    }

    struct Status: Equatable {
        var arc: Float
        var remaining: Float
        var lateral: Float
        var nextStepIndex: Int?
        var distanceToNextStep: Float
        var offRoute: Bool
        var reachedEnd: Bool
    }

    mutating func update(position: Vec3) -> Status {
        if let projection = index.project(position, hint: arc) {
            arc = projection.arc
            lateral = projection.distance
        }
        let remaining = max(0, index.total - arc)
        let endDistance = index.points.last.map { Geo.flatDistance($0, position) } ?? 0
        let reachedEnd = index.points.count < 2 || (remaining <= arrivalRadius && endDistance <= arrivalRadius + 1)
        let next = steps.firstIndex { $0.kind != .start && $0.arc > arc + 0.3 }
            ?? (steps.isEmpty ? nil : steps.count - 1)
        let distance = next.map { max(0, steps[$0].arc - arc) } ?? 0
        return Status(arc: arc, remaining: remaining, lateral: lateral, nextStepIndex: next,
                      distanceToNextStep: distance, offRoute: lateral > offRouteDistance, reachedEnd: reachedEnd)
    }
}

enum DistanceText {
    static func string(_ metres: Float, imperial: Bool) -> String {
        if imperial {
            let feet = metres * 3.28084
            if feet < 10 { return "\(Int(feet.rounded())) ft" }
            if feet < 1000 { return "\(Int((feet / 5).rounded()) * 5) ft" }
            return String(format: "%.1f mi", metres / 1609.34)
        }
        if metres < 1 { return "1 m" }
        if metres < 1000 { return "\(Int(metres.rounded())) m" }
        return String(format: "%.1f km", metres / 1000)
    }

    /// Spoken variant ("12 meters").
    static func spoken(_ metres: Float, imperial: Bool) -> String {
        if imperial {
            let feet = max(1, Int((metres * 3.28084).rounded()))
            return feet == 1 ? "1 foot" : "\(feet) feet"
        }
        let m = max(1, Int(metres.rounded()))
        return m == 1 ? "1 meter" : "\(m) meters"
    }

    /// Walking time at ~1.1 m/s.
    static func minutes(_ metres: Float) -> String {
        let minutes = max(1, Int((metres / 1.1 / 60).rounded(.up)))
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }
}
