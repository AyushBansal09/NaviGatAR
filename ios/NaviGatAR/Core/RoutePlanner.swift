import Foundation

/// One continuously-tracked part of a trip. A leg starts at a location whose
/// QR sign defines the leg's coordinate frame and ends either at the
/// destination or at a connector (elevator, stairs…).
struct RouteLeg: Hashable {
    var startID: UUID
    var endID: UUID
    /// Path in the leg frame (= frame of the start sign).
    var points: [Vec3]
    var notes: [RouteNote]
    /// Pose of every location sign passed on this leg, in the leg frame.
    /// Scanning any of them re-aligns the AR path.
    var nodePoses: [UUID: Pose]
    var locationIDs: [UUID]
    /// Connector to take after finishing this leg, oriented in travel direction.
    var exitConnector: ConnectorStep?

    var length: Float { Geo.flatLength(points) }
}

struct ConnectorStep: Hashable {
    var kind: ConnectorKind
    var fromID: UUID
    var toID: UUID
    var extraInstruction: String
}

struct PlannedRoute: Hashable {
    var startID: UUID
    var destinationID: UUID
    var legs: [RouteLeg]
    var locationPath: [UUID]

    var walkingLength: Float { legs.reduce(0) { $0 + $1.length } }

    /// Index of the leg in which `locationID`'s sign can be used for
    /// alignment, searching from `startingAt` first.
    func legIndex(containing locationID: UUID, startingAt start: Int = 0) -> Int? {
        let order = Array(max(0, start)..<legs.count) + Array(0..<min(max(0, start), legs.count))
        return order.first { legs[$0].nodePoses[locationID] != nil }
    }
}

enum RoutePlanner {
    struct Edge {
        var segment: Segment
        var forward: Bool
        var from: UUID { forward ? segment.fromID : segment.toID }
        var to: UUID { forward ? segment.toID : segment.fromID }
        var cost: Float {
            switch segment.kind {
            case .walk: return max(segment.length, 0.5)
            case .connector: return segment.cost ?? 15
            }
        }
    }

    static func edges(in building: Building, stepFreeOnly: Bool) -> [UUID: [Edge]] {
        var result: [UUID: [Edge]] = [:]
        for segment in building.segments where segment.isUsable {
            if stepFreeOnly && !segment.stepFree { continue }
            result[segment.fromID, default: []].append(Edge(segment: segment, forward: true))
            if segment.bidirectional {
                result[segment.toID, default: []].append(Edge(segment: segment, forward: false))
            }
        }
        return result
    }

    /// Cheapest sequence of edges between two locations (Dijkstra).
    static func shortestPath(in building: Building, from: UUID, to: UUID, stepFreeOnly: Bool) -> [Edge]? {
        if from == to { return [] }
        let graph = edges(in: building, stepFreeOnly: stepFreeOnly)
        var dist: [UUID: Float] = [from: 0]
        var previous: [UUID: Edge] = [:]
        var open: Set<UUID> = [from]
        var closed = Set<UUID>()

        while let current = open.min(by: { dist[$0, default: .infinity] < dist[$1, default: .infinity] }) {
            open.remove(current)
            if current == to { break }
            closed.insert(current)
            for edge in graph[current] ?? [] where !closed.contains(edge.to) {
                let candidate = dist[current, default: .infinity] + edge.cost
                if candidate < dist[edge.to, default: .infinity] {
                    dist[edge.to] = candidate
                    previous[edge.to] = edge
                    open.insert(edge.to)
                }
            }
        }

        guard previous[to] != nil else { return nil }
        var path: [Edge] = []
        var node = to
        while node != from, let edge = previous[node] {
            path.append(edge)
            node = edge.from
        }
        return path.reversed()
    }

    static func plan(in building: Building, from: UUID, to: UUID, stepFreeOnly: Bool) -> PlannedRoute? {
        guard building.location(from) != nil, building.location(to) != nil,
              let path = shortestPath(in: building, from: from, to: to, stepFreeOnly: stepFreeOnly)
        else { return nil }

        var legs: [RouteLeg] = []
        var leg = RouteLeg(startID: from, endID: from, points: [], notes: [],
                           nodePoses: [from: .identity], locationIDs: [from], exitConnector: nil)
        var current = Pose.identity
        var locationPath = [from]

        for edge in path {
            switch edge.segment.kind {
            case .walk:
                let (points, notes, end) = orientedGeometry(of: edge)
                leg.points.append(contentsOf: points.map(current.apply))
                leg.notes.append(contentsOf: notes.map { RouteNote(id: $0.id, position: current.apply($0.position), text: $0.text) })
                current = current * end
                leg.nodePoses[edge.to] = current
                leg.locationIDs.append(edge.to)
                leg.endID = edge.to
            case .connector:
                leg.exitConnector = ConnectorStep(kind: edge.segment.connectorKind ?? .other,
                                                  fromID: edge.from, toID: edge.to,
                                                  extraInstruction: edge.forward ? edge.segment.instruction : "")
                legs.append(leg)
                current = .identity
                leg = RouteLeg(startID: edge.to, endID: edge.to, points: [], notes: [],
                               nodePoses: [edge.to: .identity], locationIDs: [edge.to], exitConnector: nil)
            }
            locationPath.append(edge.to)
        }
        legs.append(leg)
        return PlannedRoute(startID: from, destinationID: to, legs: legs, locationPath: locationPath)
    }

    /// Geometry of a walk edge expressed in the frame of the sign it starts from.
    static func orientedGeometry(of edge: Edge) -> (points: [Vec3], notes: [RouteNote], end: Pose) {
        let segment = edge.segment
        let end = segment.endPose ?? .identity
        if edge.forward { return (segment.points, segment.notes, end) }
        let back = end.inverse()
        let points = segment.points.reversed().map(back.apply)
        let notes = segment.notes.map { RouteNote(id: $0.id, position: back.apply($0.position), text: $0.text) }
        return (points, notes, back)
    }

    static func connectorText(_ step: ConnectorStep, in building: Building) -> String {
        let target = building.location(step.toID)
        let place: String
        if let target, !target.floor.isEmpty {
            place = "floor \(target.floor)"
        } else {
            place = target?.name ?? "the next area"
        }
        var text: String
        switch step.kind {
        case .elevator: text = "Take the elevator to \(place)"
        case .stairs: text = "Take the stairs to \(place)"
        case .escalator: text = "Take the escalator to \(place)"
        case .door: text = "Go through the door to \(target?.name ?? place)"
        case .other: text = "Continue to \(target?.name ?? place)"
        }
        if !step.extraInstruction.isEmpty { text += ". \(step.extraInstruction)" }
        return text
    }
}
