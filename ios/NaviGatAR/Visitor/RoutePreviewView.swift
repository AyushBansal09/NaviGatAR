import SwiftUI

/// Summary of a planned trip before the camera starts.
struct RoutePreviewView: View {
    let building: Building
    let startID: UUID?
    let destinationID: UUID
    let stepFreeOnly: Bool
    let onStart: (NavigationRequest) -> Void

    @AppStorage(SettingsKey.imperialUnits) private var imperial = false

    private var plan: PlannedRoute? {
        guard let startID else { return nil }
        return RoutePlanner.plan(in: building, from: startID, to: destinationID, stepFreeOnly: stepFreeOnly)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("From", value: building.location(startID)?.name ?? "Nearest scanned sign")
                LabeledContent("To", value: building.location(destinationID)?.name ?? "—")
                if stepFreeOnly {
                    Label("Step-free routes only", systemImage: "figure.roll")
                }
            }

            if startID == nil {
                Section {
                    Text("When the camera opens, point it at any NaviGatAR QR sign near you. The route starts from that sign.")
                }
                startSection
            } else if startID == destinationID {
                Section { Text("You're already at your destination.") }
            } else if let plan {
                Section("Overview") {
                    LabeledContent("Walking distance", value: DistanceText.string(plan.walkingLength, imperial: imperial))
                    LabeledContent("Estimated time", value: DistanceText.minutes(plan.walkingLength))
                    LabeledContent("Stops on the way", value: "\(max(0, plan.locationPath.count - 2))")
                }
                startSection
                ForEach(Array(plan.legs.enumerated()), id: \.offset) { offset, leg in
                    Section(plan.legs.count > 1 ? "Part \(offset + 1)" : "Directions") {
                        ForEach(steps(for: leg)) { step in
                            HStack(spacing: 12) {
                                Image(systemName: step.symbol)
                                    .frame(width: 28)
                                    .foregroundStyle(Brand.purple)
                                Text(step.text)
                                Spacer()
                                if step.arc > 0 {
                                    Text(DistanceText.string(step.arc, imperial: imperial))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView("No route yet", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                           description: Text(stepFreeOnly
                                               ? "There's no recorded step-free route between these places. Try turning off “Step-free route”, or ask the building manager to record one."
                                               : "There's no recorded route between these places. Ask the building manager to record one in the Manage tab."))
                }
            }
        }
        .navigationTitle("Your route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var startSection: some View {
        Section {
            Button {
                onStart(NavigationRequest(building: building, startID: startID, destinationID: destinationID,
                                          stepFreeOnly: stepFreeOnly))
            } label: {
                Label("Start AR navigation", systemImage: "arkit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .listRowBackground(Color.clear)
        }
    }

    private func steps(for leg: RouteLeg) -> [NavStep] {
        let finalText: String
        if let connector = leg.exitConnector {
            finalText = RoutePlanner.connectorText(connector, in: building)
        } else {
            finalText = "Arrive at \(building.location(destinationID)?.name ?? "destination")"
        }
        return DirectionsBuilder.steps(points: leg.points, notes: leg.notes, finalText: finalText,
                                       finalIsConnector: leg.exitConnector != nil)
    }
}

/// "Need help? Or suggest an improvement." Saved for the building manager and
/// shareable through Messages/Mail.
struct FeedbackView: View {
    let buildingID: UUID?
    @Environment(BuildingStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var category: Feedback.Category = .help
    @State private var message = ""
    @State private var saved = false

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Topic", selection: $category) {
                        ForEach(Feedback.Category.allCases) { Text($0.title).tag($0) }
                    }
                    TextField("Tell us what happened or what would help", text: $message, axis: .vertical)
                        .lineLimit(4...10)
                }
                Section {
                    if category == .help {
                        Text("Lost? Look for the nearest NaviGatAR QR sign and scan it, or ask staff at the information desk.")
                            .font(.footnote)
                    }
                    if buildingID != nil {
                        Text("Your message is saved on this iPhone for the building manager. You can also share it directly.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if !trimmed.isEmpty {
                    Section {
                        ShareLink(item: "NaviGatAR – \(category.title): \(trimmed)") {
                            Label("Share message", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Help & feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let buildingID {
                            store.addFeedback(Feedback(category: category, message: trimmed), to: buildingID)
                        }
                        saved = true
                    }
                    .disabled(trimmed.isEmpty || buildingID == nil)
                }
            }
            .alert("Thank you!", isPresented: $saved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your feedback was saved.")
            }
        }
    }
}
