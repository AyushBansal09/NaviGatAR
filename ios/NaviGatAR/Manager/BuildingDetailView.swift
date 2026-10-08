import SwiftUI

struct BuildingDetailView: View {
    let buildingID: UUID
    @Environment(BuildingStore.self) private var store
    @AppStorage(SettingsKey.imperialUnits) private var imperial = false
    @State private var editingLocation: Location?
    @State private var showRecordSetup = false
    @State private var showConnector = false
    @State private var sharedFile: SharedFile?
    @State private var renaming = false
    @State private var newName = ""
    @State private var errorMessage: String?

    var body: some View {
        if let building = store.building(buildingID) {
            content(building)
        } else {
            ContentUnavailableView("Building removed", systemImage: "building.2")
        }
    }

    private func content(_ building: Building) -> some View {
        List {
            Section {
                ForEach(building.sortedLocations) { location in
                    NavigationLink {
                        LocationDetailView(buildingID: buildingID, locationID: location.id)
                    } label: {
                        LocationRow(location: location)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            store.update(buildingID) { $0.removeLocation(location.id) }
                        }
                    }
                }
                Button {
                    editingLocation = Location(name: "")
                } label: {
                    Label("Add location", systemImage: "plus.circle")
                }
            } header: {
                Text("Locations (\(building.locations.count))")
            } footer: {
                Text("Every location gets a QR sign. Visitors scan signs to start and to stay on track.")
            }

            Section {
                ForEach(building.segments) { segment in
                    SegmentRow(building: building, segment: segment, imperial: imperial)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                store.update(buildingID) { b in b.segments.removeAll { $0.id == segment.id } }
                            }
                        }
                }
                Button {
                    showRecordSetup = true
                } label: {
                    Label("Record a walking route", systemImage: "figure.walk.motion")
                }
                .disabled(building.locations.count < 2)
                Button {
                    showConnector = true
                } label: {
                    Label("Add elevator / stairs link", systemImage: "arrow.up.arrow.down.square")
                }
                .disabled(building.locations.count < 2)
            } header: {
                Text("Routes (\(building.segments.count))")
            } footer: {
                Text("Routes between neighbouring places are enough — NaviGatAR chains them together to reach any destination.")
            }

            let unreachable = building.unreachableLocations()
            if !unreachable.isEmpty {
                Section("Needs attention") {
                    Label {
                        Text("Not connected to the rest yet: \(unreachable.map(\.name).joined(separator: ", ")). Record a route to them.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                }
            }

            Section("Share") {
                Button {
                    share { try QRSignSheet.makePDF(for: building) }
                } label: {
                    Label("Print QR signs (PDF)", systemImage: "printer")
                }
                .disabled(building.locations.isEmpty)
                Button {
                    share { try store.exportFile(for: buildingID) }
                } label: {
                    Label("Share building file", systemImage: "square.and.arrow.up")
                }
                Button {
                    newName = building.name
                    renaming = true
                } label: {
                    Label("Rename building", systemImage: "pencil")
                }
            }

            if !building.feedback.isEmpty {
                Section("Visitor feedback (\(building.feedback.count))") {
                    ForEach(building.feedback.sorted { $0.date > $1.date }) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.category.title).font(.caption.bold()).foregroundStyle(Brand.purple)
                                Spacer()
                                Text(item.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(item.message)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                store.update(buildingID) { b in b.feedback.removeAll { $0.id == item.id } }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(building.name)
        .sheet(item: $editingLocation) { location in
            LocationEditView(buildingID: buildingID, location: location)
        }
        .sheet(isPresented: $showRecordSetup) {
            RecordSetupView(building: building)
        }
        .sheet(isPresented: $showConnector) {
            ConnectorEditView(building: building)
        }
        .sheet(item: $sharedFile) { file in
            ActivityView(items: [file.url])
        }
        .alert("Rename building", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { store.update(buildingID) { $0.name = name } }
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func share(_ makeFile: () throws -> URL) {
        do {
            sharedFile = SharedFile(url: try makeFile())
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SegmentRow: View {
    let building: Building
    let segment: Segment
    let imperial: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: segment.kind == .walk ? "figure.walk" : (segment.connectorKind ?? .other).symbol)
                .frame(width: 28)
                .foregroundStyle(Brand.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(building.location(segment.fromID)?.name ?? "?") \(segment.bidirectional ? "↔" : "→") \(building.location(segment.toID)?.name ?? "?")")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    if segment.kind == .walk {
                        Text(DistanceText.string(segment.length, imperial: imperial))
                        if !segment.notes.isEmpty { Text("\(segment.notes.count) note\(segment.notes.count == 1 ? "" : "s")") }
                    } else {
                        Text((segment.connectorKind ?? .other).title)
                    }
                    if segment.stepFree { Image(systemName: "figure.roll").accessibilityLabel("Step-free") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct LocationEditView: View {
    let buildingID: UUID
    @State var location: Location
    @Environment(BuildingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { store.building(buildingID)?.location(location.id) == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Room 360", text: $location.name)
                    Picker("Type", selection: $location.category) {
                        ForEach(LocationCategory.allCases) { category in
                            Label(category.title, systemImage: category.symbol).tag(category)
                        }
                    }
                    TextField("Floor (optional)", text: $location.floor)
                    TextField("Details (optional), e.g. Innovation Studio", text: $location.detail)
                }
            }
            .navigationTitle(isNew ? "New location" : "Edit location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = location
                        saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.update(buildingID) { building in
                            if let index = building.locations.firstIndex(where: { $0.id == saved.id }) {
                                building.locations[index] = saved
                            } else {
                                building.locations.append(saved)
                            }
                        }
                        dismiss()
                    }
                    .disabled(location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct LocationDetailView: View {
    let buildingID: UUID
    let locationID: UUID
    @Environment(BuildingStore.self) private var store
    @State private var editing: Location?
    @State private var sharedFile: SharedFile?
    @State private var errorMessage: String?

    var body: some View {
        if let building = store.building(buildingID), let location = building.location(locationID) {
            List {
                Section {
                    VStack(spacing: 12) {
                        if let image = QRCodeImage.make(building: building, location: location) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260)
                                .accessibilityLabel("QR sign for \(location.name)")
                        }
                        Text(location.name).font(.title2.bold())
                        if !location.subtitle.isEmpty {
                            Text(location.subtitle).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                Section {
                    Button {
                        do {
                            sharedFile = SharedFile(url: try QRSignSheet.makePDF(for: building, locations: [location]))
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    } label: {
                        Label("Print or share this sign", systemImage: "printer")
                    }
                    Button {
                        editing = location
                    } label: {
                        Label("Edit details", systemImage: "pencil")
                    }
                } footer: {
                    Text("Mount the sign flat on a wall at eye level where people naturally stop, e.g. next to a door. The same sign is used when recording routes.")
                }
                let segments = building.segments(touching: locationID)
                Section("Routes from here (\(segments.count))") {
                    if segments.isEmpty {
                        Text("No routes yet.").foregroundStyle(.secondary)
                    }
                    ForEach(segments) { segment in
                        SegmentRow(building: building, segment: segment, imperial: false)
                    }
                }
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { location in
                LocationEditView(buildingID: buildingID, location: location)
            }
            .sheet(item: $sharedFile) { file in
                ActivityView(items: [file.url])
            }
            .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        } else {
            ContentUnavailableView("Location removed", systemImage: "mappin.slash")
        }
    }
}
