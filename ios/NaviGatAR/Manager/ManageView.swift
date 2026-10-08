import SwiftUI
import UniformTypeIdentifiers

/// Building manager home: create, import and open buildings.
struct ManageView: View {
    @Environment(BuildingStore.self) private var store
    @State private var showNewBuilding = false
    @State private var newName = ""
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var pendingDelete: Building?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.sortedBuildings) { building in
                        NavigationLink(value: building.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(building.name).font(.headline)
                                Text("\(building.locations.count) locations · \(building.segments.count) routes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { pendingDelete = building }
                        }
                    }
                } footer: {
                    if store.buildings.isEmpty {
                        Text("Create a building to start. Then add its locations, print their QR signs and record the walking routes between them.")
                    }
                }

                Section("How it works") {
                    HowToRow(number: 1, text: "Add the places people look for: entrances, rooms, restrooms, elevators.")
                    HowToRow(number: 2, text: "Print each location's QR sign and mount it on a wall at eye level.")
                    HowToRow(number: 3, text: "Record routes: scan the start sign, walk to the next place, scan its sign.")
                    HowToRow(number: 4, text: "Link floors with elevator or stairs connections.")
                    HowToRow(number: 5, text: "Share the building file with other phones, or let visitors use this one.")
                }
            }
            .navigationTitle("Manage")
            .navigationDestination(for: UUID.self) { id in
                BuildingDetailView(buildingID: id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newName = ""
                            showNewBuilding = true
                        } label: {
                            Label("New building", systemImage: "plus")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import building file", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add building")
                }
            }
            .alert("New building", isPresented: $showNewBuilding) {
                TextField("Name, e.g. Engineering Hall", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { store.addBuilding(name: name) }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        let building = try store.importBuilding(from: url)
                        importMessage = "Imported “\(building.name)” with \(building.locations.count) locations."
                    } catch {
                        importMessage = error.localizedDescription
                    }
                case .failure(let error):
                    importMessage = error.localizedDescription
                }
            }
            .alert("Import", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .confirmationDialog("Delete \(pendingDelete?.name ?? "building")?",
                                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete building", role: .destructive) {
                    if let building = pendingDelete { store.deleteBuilding(building.id) }
                    pendingDelete = nil
                }
            } message: {
                Text("Its locations and recorded routes will be removed from this iPhone.")
            }
        }
    }
}

struct HowToRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Brand.purple, in: Circle())
                .foregroundStyle(.white)
            Text(text).font(.subheadline)
        }
    }
}
