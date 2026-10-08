import SwiftUI

/// Full-screen trip view: AR camera with the path, plus Map and Steps modes
/// (the non-AR modes help people who get motion sick or prefer not to look
/// through the camera).
struct NavigationScreen: View {
    let request: NavigationRequest

    enum Mode: String, CaseIterable, Identifiable {
        case ar = "AR", map = "Map", steps = "Steps"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .ar: return "camera.viewfinder"
            case .map: return "map"
            case .steps: return "list.number"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: NavigationSession?
    @State private var mode: Mode = .ar
    @State private var showFeedback = false
    private let settings = GuidanceSettings.current

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !ARSessionController.isSupported {
                unsupportedView
            } else if let session {
                content(session)
            }
        }
        .onAppear {
            guard ARSessionController.isSupported, session == nil else { return }
            UIApplication.shared.isIdleTimerDisabled = true
            let newSession = NavigationSession(request: request, controller: ARSessionController(), settings: settings)
            session = newSession
            newSession.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session?.stop()
        }
        .sensoryFeedback(.selection, trigger: settings.haptics ? session?.nextStepIndex : nil)
        .sensoryFeedback(.success, trigger: session?.phase == .arrived) { _, arrived in settings.haptics && arrived }
        .sensoryFeedback(.warning, trigger: session?.status?.offRoute == true) { _, off in settings.haptics && off }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(buildingID: request.isDemo ? nil : request.building.id)
        }
        .statusBarHidden(mode == .ar)
    }

    @ViewBuilder
    private func content(_ session: NavigationSession) -> some View {
        ARViewContainer(controller: session.ar)
            .ignoresSafeArea()
            .accessibilityHidden(true)

        if mode != .ar {
            Group {
                if mode == .map {
                    MapRouteView(session: session)
                } else {
                    StepsListView(session: session)
                }
            }
            .background(Color(.systemBackground))
            .padding(.top, 150)
            .ignoresSafeArea(edges: .bottom)
        }

        VStack(spacing: 10) {
            InstructionCard(session: session, largeText: settings.largeText, highContrast: settings.highContrast)
            if let banner = session.banner {
                Text(banner)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let message = session.tracking.message, mode == .ar, session.phase != .arrived {
                Label(message, systemImage: "camera.metering.unknown")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            phaseActions(session)
            controlBar(session)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.25), value: session.banner)

        if session.phase == .arrived {
            if !reduceMotion { ConfettiView().ignoresSafeArea() }
            arrivedCard(session)
        }
    }

    @ViewBuilder
    private func phaseActions(_ session: NavigationSession) -> some View {
        switch session.phase {
        case .scanning where !request.isDemo:
            if session.canAlignWithoutCode {
                Button {
                    session.alignWithoutCode()
                } label: {
                    Label("Can't scan? Stand facing the sign and tap here", systemImage: "scope")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black.opacity(0.6))
            }
        case .connector:
            Button {
                session.continueAfterConnector()
            } label: {
                Label("I've arrived on the next floor", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .failed:
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        default:
            EmptyView()
        }
    }

    private func controlBar(_ session: NavigationSession) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .frame(width: 48, height: 48)
                    .background(.red, in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("End navigation")

            Picker("View", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

            Button {
                showFeedback = true
            } label: {
                Image(systemName: "questionmark.bubble")
                    .font(.title3.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Get help or suggest an improvement")
        }
    }

    private func arrivedCard(_ session: NavigationSession) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Brand.purple)
            Text("You have arrived!")
                .font(.title.bold())
            Text(session.destinationName)
                .font(.title3)
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(32)
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arkit")
                .font(.system(size: 56))
            Text("AR isn't available here")
                .font(.title2.bold())
            Text("NaviGatAR's live directions need the camera of an iPhone that supports ARKit. The Simulator can't run AR — please run the app on your iPhone.")
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}

/// The big instruction banner at the top of the screen.
struct InstructionCard: View {
    let session: NavigationSession
    let largeText: Bool
    let highContrast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: session.instructionSymbol)
                .font(.system(size: largeText ? 44 : 34, weight: .bold))
                .frame(width: largeText ? 64 : 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let progress = session.legProgressText {
                    Text(progress).font(.caption.weight(.semibold)).opacity(0.8)
                }
                Text(session.instructionTitle)
                    .font(largeText ? .title.bold() : .title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(session.instructionDetail)
                    .font(largeText ? .title3 : .subheadline)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(highContrast ? Color.black : Color.white)
        .padding(16)
        .background(highContrast ? Color.yellow : Brand.purple.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 6, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Step-by-step list of the current part of the route.
struct StepsListView: View {
    let session: NavigationSession

    var body: some View {
        List {
            Section {
                ForEach(session.steps) { step in
                    let isNext = step.id == session.nextStepIndex
                    let passed = session.nextStepIndex.map { step.id < $0 } ?? false
                    HStack(spacing: 14) {
                        Image(systemName: step.symbol)
                            .font(.title3)
                            .frame(width: 32)
                            .foregroundStyle(isNext ? Brand.purple : .secondary)
                        VStack(alignment: .leading) {
                            Text(step.text).font(isNext ? .headline : .body)
                            if step.arc > 0 {
                                Text("at \(session.settings.distance(step.arc))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .opacity(passed ? 0.45 : 1)
                    .listRowBackground(isNext ? Brand.lavender : nil)
                }
            } header: {
                Text("Directions to \(session.destinationName)")
            } footer: {
                if session.steps.isEmpty {
                    Text("Directions appear once a route is found.")
                }
            }
        }
    }
}
