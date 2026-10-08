import SwiftUI

@main
struct NaviGatARApp: App {
    @State private var store = BuildingStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .tint(Brand.purple)
                .onOpenURL { url in
                    router.handle(url: url, store: store)
                }
        }
    }
}

enum AppTab: Hashable {
    case navigate, manage, settings
}

/// Cross-screen navigation state (tabs and deep links from scanned QR codes).
@Observable
final class AppRouter {
    var selectedTab: AppTab = .navigate
    /// Set when a sign was scanned with the Camera app: navigate from there.
    var pendingStart: QRPayload?
    var message: String?

    func handle(url: URL, store: BuildingStore) {
        guard let payload = QRPayload(url: url) else { return }
        if store.building(payload.buildingID)?.location(payload.locationID) != nil {
            pendingStart = payload
            selectedTab = .navigate
        } else {
            message = "This sign belongs to a building that isn't on this iPhone yet. Ask the venue for its NaviGatAR building file and import it in the Manage tab."
        }
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BuildingStore.self) private var store
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Navigate", systemImage: "location.north.line.fill") }
                .tag(AppTab.navigate)
            ManageView()
                .tabItem { Label("Manage", systemImage: "building.2") }
                .tag(AppTab.manage)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenOnboarding },
                                              set: { hasSeenOnboarding = !$0 })) {
            OnboardingView { hasSeenOnboarding = true }
        }
        .alert("NaviGatAR", isPresented: Binding(get: { router.message != nil },
                                                set: { if !$0 { router.message = nil } })) {
            Button("OK", role: .cancel) { router.message = nil }
        } message: {
            Text(router.message ?? "")
        }
        .alert("Storage problem", isPresented: Binding(get: { store.lastError != nil },
                                                      set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }
}
