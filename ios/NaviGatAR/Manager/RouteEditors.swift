import SwiftUI

/// Choose the two ends of a walking route before recording it in AR.
struct RecordSetupView: View {
    let building: Building
    @Environment(\.dismiss) private var dismiss
    @Environment(BuildingStore.self) private var store
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var stepFree = true
    @State private var bidirectional = true
    @State private var recording: RecordingRequest?
    @State private var savedMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Start at", selection: $fromID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(building.sortedLocations) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("End at", selection: $toID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(building.sortedLocations.filter { $0.id != fromID }) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                Section {
                    Toggle("Step-free (no stairs on the way)", isOn: $stepFree)
                    Toggle("Can be walked both ways", isOn: $bidirectional)
                }
                Section("How to record") {
                    HowToRow(number: 1, text: "Make sure both QR signs are already on the wall.")
                    HowToRow(number: 2, text: "Stand in front of the start sign and scan it.")
                    HowToRow(number: 3, text: "Walk the route at a normal pace holding the iPhone up in front of you. Add notes like “Open the door!” where helpful.")
                    HowToRow(number: 4, text: "Tap Finish and scan the sign at the end.")
                }
                Section {
                    Button {
                        if let fromID, let toID, let from = building.location(fromID), let to = building.location(toID) {
                            recording = RecordingRequest(building: building, from: from, to: to,
                                                         stepFree: stepFree, bidirectional: bidirectional)
                        }
                    } label: {
                        Label("Start recording", systemImage: "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(fromID == nil || toID == nil || fromID == toID)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Record a route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .fullScreenCover(item: $recording) { request in
                RecordRouteScreen(request: request) { segment in
                    store.update(building.id) { $0.segments.append(segment) }
                    savedMessage = "Saved a \(DistanceText.string(segment.length, imperial: GuidanceSettings.current.imperial)) route from \(request.from.name) to \(request.to.name)."
                }
            }
            .alert("Route saved", isPresented: Binding(get: { savedMessage != nil }, set: { if !$0 { savedMessage = nil } })) {
                Button("Record another") {
                    savedMessage = nil
                    fromID = toID
                    toID = nil
                }
                Button("Done") {
                    savedMessage = nil
                    dismiss()
                }
            } message: {
                Text(savedMessage ?? "")
            }
        }
    }
}

/// Elevators, stairs and other transitions that AR can't follow.
struct ConnectorEditView: View {
    let building: Building
    @Environment(\.dismiss) private var dismiss
    @Environment(BuildingStore.self) private var store
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var kind: ConnectorKind = .elevator
    @State private var stepFree = true
    @State private var bidirectional = true
    @State private var extra = ""
    @State private var cost: Double = 15

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(ConnectorKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("From", selection: $fromID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(building.sortedLocations) { Text(label(for: $0)).tag(Optional($0.id)) }
                    }
                    Picker("To", selection: $toID) {
                        Text("Choose…").tag(UUID?.none)
                        ForEach(building.sortedLocations.filter { $0.id != fromID }) { Text(label(for: $0)).tag(Optional($0.id)) }
                    }
                } footer: {
                    Text("Example: “Elevator – Floor 1” to “Elevator – Floor 3”. Put a QR sign at both ends so visitors can continue after the ride.")
                }
                Section {
                    Toggle("Step-free", isOn: $stepFree)
                    Toggle("Works both ways", isOn: $bidirectional)
                    TextField("Extra advice (optional), e.g. Use the lifts on the left", text: $extra)
                    VStack(alignment: .leading) {
                        Text("Effort: about \(Int(cost)) m of walking")
                        Slider(value: $cost, in: 5...100, step: 5)
                    }
                } footer: {
                    Text("Effort helps NaviGatAR choose between, say, stairs and a far-away elevator.")
                }
            }
            .navigationTitle("Add a link")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newKind in stepFree = newKind.defaultStepFree }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let fromID, let toID else { return }
                        let segment = Segment(fromID: fromID, toID: toID, kind: .connector, connectorKind: kind,
                                              instruction: extra.trimmingCharacters(in: .whitespacesAndNewlines),
                                              stepFree: stepFree, bidirectional: bidirectional, cost: Float(cost))
                        store.update(building.id) { $0.segments.append(segment) }
                        dismiss()
                    }
                    .disabled(fromID == nil || toID == nil || fromID == toID)
                }
            }
        }
    }

    private func label(for location: Location) -> String {
        location.floor.isEmpty ? location.name : "\(location.name) (floor \(location.floor))"
    }
}
