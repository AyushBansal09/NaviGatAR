import SwiftUI

struct SettingsView: View {
    @Environment(BuildingStore.self) private var store
    @AppStorage(SettingsKey.voiceGuidance) private var voice = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.pathStyle) private var pathStyle = PathStyle.spheres.rawValue
    @AppStorage(SettingsKey.pathColor) private var pathColor = PathColor.cyan.rawValue
    @AppStorage(SettingsKey.highContrast) private var highContrast = false
    @AppStorage(SettingsKey.largeText) private var largeText = false
    @AppStorage(SettingsKey.imperialUnits) private var imperial = false
    @AppStorage(SettingsKey.stepFreeDefault) private var stepFree = false
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = true
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Guidance") {
                    Toggle(isOn: $voice) { Label("Voice directions", systemImage: "speaker.wave.2") }
                    Toggle(isOn: $haptics) { Label("Vibrate at turns", systemImage: "iphone.radiowaves.left.and.right") }
                    Toggle(isOn: $stepFree) { Label("Prefer step-free routes", systemImage: "figure.roll") }
                    Picker(selection: $imperial) {
                        Text("Metres").tag(false)
                        Text("Feet").tag(true)
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                }

                Section {
                    Picker(selection: $pathStyle) {
                        ForEach(PathStyle.allCases) { Text($0.title).tag($0.rawValue) }
                    } label: {
                        Label("Path markers", systemImage: "circle.grid.3x3")
                    }
                    Picker(selection: $pathColor) {
                        ForEach(PathColor.allCases) { color in
                            HStack {
                                Circle().fill(color.color).frame(width: 14, height: 14)
                                Text(color.title)
                            }
                            .tag(color.rawValue)
                        }
                    } label: {
                        Label("Marker colour", systemImage: "paintpalette")
                    }
                    .disabled(highContrast)
                } header: {
                    Text("AR path")
                }

                Section {
                    Toggle(isOn: $highContrast) { Label("High contrast", systemImage: "circle.lefthalf.filled") }
                    Toggle(isOn: $largeText) { Label("Large instructions", systemImage: "textformat.size") }
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("NaviGatAR also follows your iPhone's text size, VoiceOver and Reduce Motion settings. Use Map or Steps mode during navigation if looking through the camera is uncomfortable.")
                }

                Section("Help") {
                    Button {
                        hasSeenOnboarding = false
                    } label: {
                        Label("Show the tutorial again", systemImage: "questionmark.circle")
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("How NaviGatAR works", systemImage: "info.circle")
                    }
                }

                Section {
                    Button("Delete all buildings on this iPhone", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all buildings?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) { store.deleteAll() }
            } message: {
                Text("All locations, routes and feedback on this iPhone will be removed. Shared building files are not affected.")
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section("Positioning") {
                Text("Every location has a QR sign on the wall. When you scan one, NaviGatAR measures exactly where the sign is and which way the wall faces, then places the recorded path in the room around you.")
                Text("While you walk, ARKit follows the iPhone's movement with the camera and motion sensors (and LiDAR on Pro models). Scanning another sign on the way corrects any drift.")
            }
            Section("Routes") {
                Text("Building managers record routes by walking them once. NaviGatAR chains recorded routes together and picks the shortest one, or a step-free one if you ask for it.")
                Text("Elevators and stairs between floors are added as links: you follow the instruction and scan the sign when you get out.")
            }
            Section("Privacy") {
                Text("Everything stays on your iPhone. The camera image is only analysed on the device to find signs and track movement; nothing is uploaded and no account is needed.")
            }
            Section("Safety") {
                Text("Stay aware of your surroundings. Glance at the screen, don't stare at it, and stop walking before reading longer notes.")
            }
        }
        .navigationTitle("How it works")
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, title: String, text: String)] = [
        ("location.north.line.fill", "Find your way indoors",
         "NaviGatAR guides you through airports, malls, hospitals and campuses with markers drawn right in the camera view."),
        ("qrcode.viewfinder", "Scan a sign to start",
         "Look for a NaviGatAR QR sign on the wall. Scanning it tells the app exactly where you are — no GPS needed."),
        ("circle.dotted.and.circle", "Follow the markers",
         "Walk along the floating markers. Voice, vibration, a map and a step list help too. Scan another sign anytime to stay on track."),
        ("building.2", "Run a building?",
         "Use the Manage tab to add locations, print their signs and record routes by walking them once."),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: item.symbol)
                            .font(.system(size: 84, weight: .semibold))
                            .foregroundStyle(Brand.purple)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(item.text)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .background(Brand.lavender.opacity(0.4).ignoresSafeArea())
    }
}
