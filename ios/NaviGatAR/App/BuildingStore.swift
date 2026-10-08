import Foundation
import Observation

/// Keeps every building on this device and saves them as JSON in
/// Application Support. Everything works offline.
@Observable
final class BuildingStore {
    private(set) var buildings: [Building] = []
    var lastError: String?

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true))
                ?? FileManager.default.temporaryDirectory
            self.fileURL = base.appendingPathComponent("NaviGatAR", isDirectory: true)
                .appendingPathComponent("buildings.json")
        }
        load()
    }

    // MARK: Queries

    func building(_ id: UUID?) -> Building? {
        guard let id else { return nil }
        return buildings.first { $0.id == id }
    }

    var sortedBuildings: [Building] {
        buildings.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: Mutations

    @discardableResult
    func addBuilding(name: String, address: String = "") -> Building {
        let building = Building(name: name.trimmingCharacters(in: .whitespacesAndNewlines), address: address)
        buildings.append(building)
        save()
        return building
    }

    /// Applies `change` to the building with `id` and saves.
    func update(_ id: UUID, _ change: (inout Building) -> Void) {
        guard let index = buildings.firstIndex(where: { $0.id == id }) else { return }
        var building = buildings[index]
        change(&building)
        building.updatedAt = Date()
        buildings[index] = building
        save()
    }

    func deleteBuilding(_ id: UUID) {
        buildings.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        buildings.removeAll()
        save()
    }

    func addFeedback(_ feedback: Feedback, to buildingID: UUID) {
        update(buildingID) { $0.feedback.append(feedback) }
    }

    // MARK: Import / export

    /// Imports a shared building file. A building with the same id is replaced.
    @discardableResult
    func importBuilding(from url: URL) throws -> Building {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let building = try BuildingFile.decode(try Data(contentsOf: url))
        if let index = buildings.firstIndex(where: { $0.id == building.id }) {
            buildings[index] = building
        } else {
            buildings.append(building)
        }
        save()
        return building
    }

    /// Writes a shareable copy of the building to a temporary file.
    func exportFile(for id: UUID) throws -> URL {
        guard let building = building(id) else { throw CocoaError(.fileNoSuchFile) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(BuildingFile.suggestedFileName(for: building))
        try BuildingFile.encode(building).write(to: url, options: .atomic)
        return url
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            buildings = try decoder.decode([Building].self, from: data)
        } catch {
            lastError = "Couldn't read saved buildings: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(buildings).write(to: fileURL, options: .atomic)
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
