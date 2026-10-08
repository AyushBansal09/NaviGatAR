import Observation
import SwiftUI

struct RecordingRequest: Identifiable {
    let id = UUID()
    var building: Building
    var from: Location
    var to: Location
    var stepFree: Bool
    var bidirectional: Bool
}

/// Records a walking route in AR: scan start sign → walk → scan end sign.
@Observable
final class RecordingSession {
    enum Phase: Equatable {
        case waitingForStart
        case recording
        case waitingForEnd
        case done
        case failed(String)
    }

    let request: RecordingRequest
    let ar: ARSessionController
    private(set) var phase: Phase = .waitingForStart
    private(set) var distance: Float = 0
    private(set) var noteCount = 0
    private(set) var tracking: TrackingStatus = .unavailable
    private(set) var banner: String?
    private(set) var startQuality: AnchorQuality?

    @ObservationIgnored private var recorder: RouteRecorder?
    @ObservationIgnored private var bannerToken = 0
    @ObservationIgnored var onFinished: ((Segment) -> Void)?

    init(request: RecordingRequest, controller: ARSessionController) {
        self.request = request
        self.ar = controller
    }

    func start() {
        ar.onCodeDetected = { [weak self] payload, estimate in self?.handleCode(payload, estimate) }
        ar.onCamera = { [weak self] camera in self?.handleCamera(camera) }
        ar.onTracking = { [weak self] status in self?.tracking = status }
        ar.onError = { [weak self] message in self?.phase = .failed(message) }
        ar.start()
    }

    func stop() {
        ar.onCodeDetected = nil
        ar.onCamera = nil
        ar.onTracking = nil
        ar.onError = nil
        ar.pause()
    }

    var title: String {
        switch phase {
        case .waitingForStart: return "Scan the sign at \(request.from.name)"
        case .recording: return "Recording… walk to \(request.to.name)"
        case .waitingForEnd: return "Scan the sign at \(request.to.name)"
        case .done: return "Route saved"
        case .failed: return "Recording stopped"
        }
    }

    var detail: String {
        switch phase {
        case .waitingForStart: return "Stand in front of the sign and point the camera at it."
        case .recording: return "Hold the iPhone up and walk at a normal pace."
        case .waitingForEnd: return "Point the camera at the sign to finish. Keep walking toward it if needed."
        case .done: return ""
        case .failed(let message): return message
        }
    }

    // MARK: Actions

    func startWithoutCode() {
        guard let camera = ar.latestCamera, ar.tracking == .normal else {
            flash("Move your iPhone slowly until AR is ready.")
            return
        }
        begin(at: .estimatedAnchor(cameraPosition: camera.position, cameraForward: camera.forward), quality: .approximate)
    }

    func addNote(_ text: String) {
        guard var recorder = self.recorder, let camera = ar.latestCamera else { return }
        recorder.addNote(text, cameraPosition: camera.position)
        self.recorder = recorder
        if let note = recorder.notes.last { ar.renderer.addNoteLabel(note.text, at: note.position) }
        noteCount = recorder.notes.count
    }

    func requestFinish() {
        guard phase == .recording else { return }
        phase = .waitingForEnd
    }

    func finishWithoutCode() {
        guard let camera = ar.latestCamera else { return }
        complete(endAnchor: .estimatedAnchor(cameraPosition: camera.position, cameraForward: camera.forward))
    }

    // MARK: Events

    private func handleCode(_ payload: String, _ estimate: QRAnchorEstimator.Estimate) {
        guard let code = QRPayload(string: payload), code.buildingID == request.building.id else {
            flash("That code isn't a sign for \(request.building.name).")
            return
        }
        let name = request.building.location(code.locationID)?.name ?? "another location"
        switch phase {
        case .waitingForStart:
            if code.locationID == request.from.id {
                begin(at: estimate.pose, quality: estimate.quality)
            } else {
                flash("That's the sign for \(name). Scan \(request.from.name) to start.")
            }
        case .recording, .waitingForEnd:
            if code.locationID == request.to.id {
                complete(endAnchor: estimate.pose)
            } else if code.locationID != request.from.id {
                flash("That's \(name). Finish at \(request.to.name).")
            }
        default:
            break
        }
    }

    private func handleCamera(_ camera: CameraSample) {
        guard phase == .recording || phase == .waitingForEnd, ar.tracking == .normal,
              var recorder = self.recorder else { return }
        if let point = recorder.add(cameraPosition: camera.position) {
            ar.renderer.addBreadcrumb(point)
        }
        self.recorder = recorder
        distance = recorder.length
    }

    private func begin(at anchor: Pose, quality: AnchorQuality) {
        recorder = RouteRecorder(startAnchor: anchor)
        startQuality = quality
        ar.renderer.clear()
        ar.renderer.setAlignment(anchor)
        ar.renderer.setVisible(true)
        ar.renderer.addSignOutline(.identity)
        if let camera = ar.latestCamera, var recorder = self.recorder {
            if let point = recorder.add(cameraPosition: camera.position) { ar.renderer.addBreadcrumb(point) }
            self.recorder = recorder
        }
        phase = .recording
        flash(quality == .precise ? "Start sign found. Start walking!" : "Started (approximate). Start walking!")
    }

    private func complete(endAnchor: Pose) {
        guard let recorder else { return }
        guard recorder.length >= 1 else {
            flash("Walk a bit further before finishing.")
            if phase == .waitingForEnd { phase = .recording }
            return
        }
        let segment = recorder.makeSegment(from: request.from.id, to: request.to.id, endAnchor: endAnchor,
                                           finalCameraPosition: ar.latestCamera?.position,
                                           stepFree: request.stepFree, bidirectional: request.bidirectional)
        phase = .done
        onFinished?(segment)
    }

    private func flash(_ message: String) {
        banner = message
        bannerToken += 1
        let token = bannerToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
        }
    }
}

struct RecordRouteScreen: View {
    let request: RecordingRequest
    let onSave: (Segment) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var session: RecordingSession?
    @State private var showNote = false
    @State private var noteText = ""
    @State private var confirmCancel = false
    @AppStorage(SettingsKey.imperialUnits) private var imperial = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !ARSessionController.isSupported {
                VStack(spacing: 16) {
                    Text("Recording routes needs an iPhone with ARKit. The Simulator can't run AR.")
                        .multilineTextAlignment(.center)
                    Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
                }
                .foregroundStyle(.white)
                .padding()
            } else if let session {
                ARViewContainer(controller: session.ar).ignoresSafeArea()
                overlay(session)
            }
        }
        .onAppear {
            guard ARSessionController.isSupported, session == nil else { return }
            UIApplication.shared.isIdleTimerDisabled = true
            let newSession = RecordingSession(request: request, controller: ARSessionController())
            newSession.onFinished = { segment in
                onSave(segment)
                dismiss()
            }
            session = newSession
            newSession.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            session?.stop()
        }
        .sensoryFeedback(.success, trigger: session?.phase == .recording) { _, recording in recording }
        .alert("Add a note here", isPresented: $showNote) {
            TextField("e.g. Open the door!", text: $noteText)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                session?.addNote(noteText)
                noteText = ""
            }
        } message: {
            Text("Visitors will see this text floating at this spot.")
        }
        .confirmationDialog("Discard this recording?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        }
    }

    @ViewBuilder
    private func overlay(_ session: RecordingSession) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: session.phase == .recording ? "record.circle" : "qrcode.viewfinder")
                    .font(.system(size: 32, weight: .bold))
                    .symbolEffect(.pulse, isActive: session.phase == .recording)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title).font(.title3.bold())
                    Text(session.detail).font(.subheadline).opacity(0.9)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding()
            .background((session.phase == .recording ? Color.red : Brand.purple).opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 20))

            if let banner = session.banner {
                Text(banner)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }
            if let message = session.tracking.message {
                Label(message, systemImage: "camera.metering.unknown")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            if session.phase == .recording || session.phase == .waitingForEnd {
                HStack {
                    Label(DistanceText.string(session.distance, imperial: imperial), systemImage: "ruler")
                    Spacer()
                    Label("\(session.noteCount) notes", systemImage: "text.bubble")
                }
                .font(.headline)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 12) {
                Button {
                    confirmCancel = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.bold())
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Cancel recording")

                switch session.phase {
                case .waitingForStart:
                    Button {
                        session.startWithoutCode()
                    } label: {
                        Text("Start here without scanning").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                case .recording:
                    Button {
                        showNote = true
                    } label: {
                        Label("Add note", systemImage: "text.bubble").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    Button {
                        session.requestFinish()
                    } label: {
                        Label("Finish", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                case .waitingForEnd:
                    Button {
                        session.finishWithoutCode()
                    } label: {
                        Text("Finish without scanning").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                case .failed:
                    Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
                case .done:
                    EmptyView()
                }
            }
            .controlSize(.large)
        }
        .padding()
    }
}
