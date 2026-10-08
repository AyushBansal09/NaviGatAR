import Foundation

enum LocationCategory: String, Codable, CaseIterable, Identifiable {
    case entrance, room, office, restroom, elevator, stairs, exit, information, food, shop, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .entrance: return "Entrance"
        case .room: return "Room"
        case .office: return "Office"
        case .restroom: return "Restroom"
        case .elevator: return "Elevator"
        case .stairs: return "Stairs"
        case .exit: return "Exit"
        case .information: return "Information desk"
        case .food: return "Food & drink"
        case .shop: return "Shop"
        case .other: return "Other"
        }
    }

    /// SF Symbol used across the app.
    var symbol: String {
        switch self {
        case .entrance: return "door.left.hand.open"
        case .room: return "square.split.bottomrightquarter"
        case .office: return "briefcase"
        case .restroom: return "toilet"
        case .elevator: return "arrow.up.arrow.down.square"
        case .stairs: return "figure.stairs"
        case .exit: return "figure.walk.departure"
        case .information: return "info.circle"
        case .food: return "fork.knife"
        case .shop: return "bag"
        case .other: return "mappin"
        }
    }
}

/// A named place inside a building. Every location gets its own QR sign.
struct Location: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var detail: String = ""
    var floor: String = ""
    var category: LocationCategory = .room

    var subtitle: String {
        [floor.isEmpty ? nil : "Floor \(floor)", detail.isEmpty ? nil : detail]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

/// A short instruction pinned to a spot along a recorded route ("Open the door!").
struct RouteNote: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var position: Vec3
    var text: String
}

enum ConnectorKind: String, Codable, CaseIterable, Identifiable {
    case elevator, stairs, escalator, door, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elevator: return "Elevator"
        case .stairs: return "Stairs"
        case .escalator: return "Escalator"
        case .door: return "Door / gate"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .elevator: return "arrow.up.arrow.down.square"
        case .stairs: return "figure.stairs"
        case .escalator: return "arrow.up.right.square"
        case .door: return "door.left.hand.open"
        case .other: return "arrow.triangle.turn.up.right.diamond"
        }
    }

    /// Whether wheelchair users can normally use this kind of connector.
    var defaultStepFree: Bool { self != .stairs && self != .escalator }
}

/// An edge in the building graph.
///
/// * `walk` segments are recorded with AR by a building manager. Their points
///   are stored in the coordinate frame of the `from` location's QR sign, and
///   `endPose` is the pose of the `to` location's sign in that same frame.
/// * `connector` segments describe a transition AR can't track well
///   (elevators, stairs between floors). The visitor follows a text
///   instruction and scans the sign at the other end to continue.
struct Segment: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case walk, connector }

    var id: UUID = UUID()
    var fromID: UUID
    var toID: UUID
    var kind: Kind
    var points: [Vec3] = []
    var endPose: Pose? = nil
    var notes: [RouteNote] = []
    var connectorKind: ConnectorKind? = nil
    /// Optional extra advice shown with a connector ("Use the lifts on the left").
    var instruction: String = ""
    var stepFree: Bool = true
    var bidirectional: Bool = true
    /// Routing cost for connectors, in metre-equivalents.
    var cost: Float? = nil
    var createdAt: Date = Date()

    var length: Float { Geo.flatLength(points) }

    var isUsable: Bool {
        switch kind {
        case .walk: return points.count >= 2 && endPose != nil
        case .connector: return true
        }
    }

    func connects(_ locationID: UUID) -> Bool { fromID == locationID || toID == locationID }
}

struct Feedback: Codable, Identifiable, Hashable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case help, suggestion, wrongDirections
        var id: String { rawValue }
        var title: String {
            switch self {
            case .help: return "I need help"
            case .suggestion: return "Suggestion"
            case .wrongDirections: return "Directions were wrong"
            }
        }
    }

    var id: UUID = UUID()
    var date: Date = Date()
    var category: Category
    var message: String
}

struct Building: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var address: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var locations: [Location] = []
    var segments: [Segment] = []
    var feedback: [Feedback] = []

    func location(_ id: UUID?) -> Location? {
        guard let id else { return nil }
        return locations.first { $0.id == id }
    }

    var sortedLocations: [Location] {
        locations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func segments(touching locationID: UUID) -> [Segment] {
        segments.filter { $0.connects(locationID) }
    }

    /// Removes a location and every route that uses it.
    mutating func removeLocation(_ id: UUID) {
        locations.removeAll { $0.id == id }
        segments.removeAll { $0.connects(id) }
    }

    /// Locations that can't be reached from the largest connected group.
    /// Used to warn managers about missing routes.
    func unreachableLocations() -> [Location] {
        guard locations.count > 1 else { return [] }
        var neighbours: [UUID: Set<UUID>] = [:]
        for s in segments where s.isUsable {
            neighbours[s.fromID, default: []].insert(s.toID)
            neighbours[s.toID, default: []].insert(s.fromID)
        }
        var seen = Set<UUID>()
        var groups: [Set<UUID>] = []
        for loc in locations where !seen.contains(loc.id) {
            var group = Set<UUID>()
            var stack = [loc.id]
            while let next = stack.popLast() {
                guard group.insert(next).inserted else { continue }
                stack.append(contentsOf: neighbours[next] ?? [])
            }
            seen.formUnion(group)
            groups.append(group)
        }
        guard let largest = groups.max(by: { $0.count < $1.count }) else { return [] }
        return sortedLocations.filter { !largest.contains($0.id) }
    }
}
