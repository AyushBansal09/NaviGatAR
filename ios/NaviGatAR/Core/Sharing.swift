import Foundation

/// Contents of a NaviGatAR location sign:
/// `navigatar://location?b=<building-id>&l=<location-id>`.
/// The custom scheme also lets the iPhone Camera app open NaviGatAR.
struct QRPayload: Hashable {
    static let scheme = "navigatar"

    var buildingID: UUID
    var locationID: UUID

    var string: String { "\(Self.scheme)://location?b=\(buildingID.uuidString)&l=\(locationID.uuidString)" }

    init(buildingID: UUID, locationID: UUID) {
        self.buildingID = buildingID
        self.locationID = locationID
    }

    init?(string: String) {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        self.init(url: url)
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let b = items.first(where: { $0.name == "b" })?.value.flatMap(UUID.init(uuidString:)),
              let l = items.first(where: { $0.name == "l" })?.value.flatMap(UUID.init(uuidString:))
        else { return nil }
        self.init(buildingID: b, locationID: l)
    }
}

/// File format used to share a building between devices.
struct BuildingFile: Codable {
    static let currentFormat = "navigatar.building"
    static let currentVersion = 1

    var format: String = BuildingFile.currentFormat
    var version: Int = BuildingFile.currentVersion
    var exportedAt: Date = Date()
    var building: Building

    enum FileError: LocalizedError {
        case notNaviGatAR, newerVersion(Int)
        var errorDescription: String? {
            switch self {
            case .notNaviGatAR: return "This file isn't a NaviGatAR building."
            case .newerVersion(let v): return "This building was saved by a newer NaviGatAR (format \(v)). Please update the app."
            }
        }
    }

    static func encode(_ building: Building) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(BuildingFile(building: building))
    }

    static func decode(_ data: Data) throws -> Building {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file: BuildingFile
        do {
            file = try decoder.decode(BuildingFile.self, from: data)
        } catch {
            throw FileError.notNaviGatAR
        }
        guard file.format == currentFormat else { throw FileError.notNaviGatAR }
        guard file.version <= currentVersion else { throw FileError.newerVersion(file.version) }
        return file.building
    }

    static func suggestedFileName(for building: Building) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = String(building.name.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespaces)
        return (cleaned.isEmpty ? "Building" : cleaned) + ".navigatar.json"
    }
}

/// A tiny built-in route used by "Try the AR demo": walk 4 m ahead, turn
/// right and walk 3 m. It is anchored to wherever the phone is when it starts.
enum DemoRoute {
    static let buildingID = UUID(uuidString: "00000000-0000-0000-0000-00000000D3E0")!
    static let startID = UUID(uuidString: "00000000-0000-0000-0000-00000000D3E1")!
    static let destinationID = UUID(uuidString: "00000000-0000-0000-0000-00000000D3E2")!

    static func building() -> Building {
        // Sign frame: +Z points back at the person, who stands 0.6 m in front.
        var points: [Vec3] = []
        var z: Float = 0.6
        while z >= -3.4 { points.append(Vec3(0, -0.1, z)); z -= 0.25 }
        var x: Float = 0.25
        while x <= 3.0 { points.append(Vec3(x, -0.1, -3.4)); x += 0.25 }

        let segment = Segment(fromID: startID, toID: destinationID, kind: .walk, points: points,
                              endPose: Pose(position: Vec3(3.6, 0, -3.4), yaw: -.pi / 2),
                              notes: [RouteNote(position: Vec3(0, -0.1, -1.6), text: "Open the door!")])
        return Building(id: buildingID, name: "AR demo",
                        locations: [Location(id: startID, name: "Your starting point", category: .entrance),
                                    Location(id: destinationID, name: "Demo destination", category: .room)],
                        segments: [segment])
    }
}
