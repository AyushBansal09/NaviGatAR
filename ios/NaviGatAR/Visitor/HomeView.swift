import SwiftUI

/// Visitor start screen: pick a building, where you are and where to go.
struct HomeView: View {
    @Environment(BuildingStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.selectedBuilding) private var selectedBuildingID = ""
    @AppStorage(SettingsKey.stepFreeDefault) private var stepFreeOnly = false

    /// nil = scan the nearest sign to find out.
    @State private var startID: UUID?
    @State private var destinationID: UUID?
    @State private var activeRequest: NavigationRequest?
    @State private var showFeedback = false
    @State private var showPreview = false

    private var building: Building? {
        store.building(UUID(uuidString: selectedBuildingID)) ?? store.sortedBuildings.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let building {
                        tripCard(building)
                    } else {
                        emptyState
                    }
                    demoCard
                    Button {
                        showFeedback = true
                    } label: {
                        Label("Need help? Or suggest an improvement", systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .background(Brand.lavender.opacity(0.35))
            .navigationTitle("NaviGatAR")
            .navigationDestination(isPresented: $showPreview) {
                if let building, let destinationID {
                    RoutePreviewView(building: building, startID: startID, destinationID: destinationID,
                                     stepFreeOnly: stepFreeOnly) { request in
                        activeRequest = request
                    }
                }
            }
        }
        .fullScreenCover(item: $activeRequest) { request in
            NavigationScreen(request: request)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(buildingID: building?.id)
        }
        .onChange(of: router.pendingStart, initial: true) { _, payload in
            guard let payload else { return }
            selectedBuildingID = payload.buildingID.uuidString
            startID = payload.locationID
            router.pendingStart = nil
        }
        .onChange(of: selectedBuildingID) { _, _ in
            // Keep choices that belong to the newly selected building (e.g. from a scanned sign).
            if building?.location(startID) == nil { startID = nil }
            if building?.location(destinationID) == nil { destinationID = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Where do you want to go?")
                    .font(.title2.bold())
                Text("Follow AR markers through the camera to your destination.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tripCard(_ building: Building) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.buildings.count > 1 {
                Menu {
                    ForEach(store.sortedBuildings) { b in
                        Button(b.name) { selectedBuildingID = b.id.uuidString }
                    }
                } label: {
                    HStack {
                        Label(building.name, systemImage: "building.2")
                            .font(.headline)
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                }
            } else {
                Label(building.name, systemImage: "building.2").font(.headline)
            }

            if building.locations.isEmpty {
                Text("This building has no locations yet. Add them in the Manage tab.")
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink {
                    LocationPickerView(building: building, title: "Starting point", allowScan: true,
                                       selection: $startID)
                } label: {
                    fieldRow(title: "From", value: building.location(startID)?.name ?? "Scan the nearest sign",
                             symbol: startID == nil ? "qrcode.viewfinder" : "smallcircle.filled.circle")
                }
                NavigationLink {
                    LocationPickerView(building: building, title: "Destination", allowScan: false,
                                       selection: $destinationID)
                } label: {
                    fieldRow(title: "To", value: building.location(destinationID)?.name ?? "Choose destination",
                             symbol: "mappin.and.ellipse")
                }

                Toggle(isOn: $stepFreeOnly) {
                    Label("Step-free route (avoid stairs)", systemImage: "figure.roll")
                }

                Button {
                    showPreview = true
                } label: {
                    Label("See route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(destinationID == nil)

                if startID == nil {
                    Text("Tip: not sure where you are? Leave “From” empty and scan any NaviGatAR QR sign nearby.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func fieldRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Brand.purple)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.medium)).foregroundStyle(.primary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Brand.lavender.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No buildings yet", systemImage: "building.2.crop.circle")
                .font(.headline)
            Text("A building manager sets up locations, prints their QR signs and records walking routes in the Manage tab. You can also import a building file shared by a venue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                router.selectedTab = .manage
            } label: {
                Label("Set up a building", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var demoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Try it anywhere", systemImage: "sparkles")
                .font(.headline)
            Text("The AR demo draws a short path from where you stand: about 4 m ahead, then right. Make sure you have some free space.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                activeRequest = .demo()
            } label: {
                Label("Start AR demo", systemImage: "arkit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

/// Searchable list of a building's locations.
struct LocationPickerView: View {
    let building: Building
    let title: String
    let allowScan: Bool
    @Binding var selection: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Location] {
        let all = building.sortedLocations
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)
                || $0.category.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            if allowScan {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    HStack {
                        Label("Scan the nearest sign when I start", systemImage: "qrcode.viewfinder")
                        Spacer()
                        if selection == nil { Image(systemName: "checkmark").foregroundStyle(Brand.purple) }
                    }
                }
            }
            Section("Locations") {
                ForEach(results) { location in
                    Button {
                        selection = location.id
                        dismiss()
                    } label: {
                        HStack {
                            LocationRow(location: location)
                            Spacer()
                            if selection == location.id { Image(systemName: "checkmark").foregroundStyle(Brand.purple) }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .searchable(text: $query, prompt: "Search rooms, floors, categories")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LocationRow: View {
    let location: Location

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: location.category.symbol)
                .frame(width: 28)
                .foregroundStyle(Brand.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                if !location.subtitle.isEmpty {
                    Text(location.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
