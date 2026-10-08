import Foundation
import Observation

struct NavigationRequest: Identifiable {
    let id = UUID()
    var building: Building
    /// nil = "find out by scanning the nearest sign".
    var startID: UUID?
    var destinationID: UUID
    var stepFreeOnly: Bool
    var isDemo = false

    static func demo() -> NavigationRequest {
        NavigationRequest(building: DemoRoute.building(), startID: DemoRoute.startID,
                          destinationID: DemoRoute.destinationID, stepFreeOnly: false, isDemo: true)
    }
}

/// Drives one trip: plans the route, aligns it to the AR world when a sign is
/// scanned, tracks progress and produces instructions.
@Observable
final class NavigationSession {
    enum Phase: Equatable {
        /// Waiting for a QR sign so the path can be placed in the room.
        case scanning
        case navigating
        /// Following an elevator/stairs instruction; the next sign continues the trip.
        case connector(String)
        case arrived
        case failed(String)
    }

    let request: NavigationRequest
    let building: Building
    let settings: GuidanceSettings
    let ar: ARSessionController

    private(set) var phase: Phase = .scanning
    private(set) var route: PlannedRoute?
    private(set) var legIndex = 0
    private(set) var steps: [NavStep] = []
    private(set) var status: LegTracker.Status?
    private(set) var tracking: TrackingStatus = .unavailable
    private(set) var startID: UUID?
    /// Visitor position/heading in the current leg's frame (for the map).
    private(set) var userPosition: Vec3?
    private(set) var userHeading: Vec3?
    private(set) var banner: String?

    private let speech = SpeechGuide()
    @ObservationIgnored private var tracker: LegTracker?
    @ObservationIgnored private var alignment: Pose?
    @ObservationIgnored private var lastAlignment: [UUID: Date] = [:]
    @ObservationIgnored private var announced: Set<String> = []
    @ObservationIgnored private var lastRenderedArc: Float = -100
    @ObservationIgnored private var lastOffRouteWarning = Date.distantPast
    @ObservationIgnored private var bannerToken = 0

    init(request: NavigationRequest, controller: ARSessionController, settings: GuidanceSettings) {
        self.request = request
        self.building = request.building
        self.settings = settings
        self.ar = controller
        speech.enabled = settings.voice
        if let start = request.startID {
            if let plan = makePlan(from: start) {
                adopt(plan)
            } else {
                phase = .failed(noRouteMessage(from: start))
            }
        }
    }

    // MARK: Lifecycle

    func start() {
        ar.onCodeDetected = { [weak self] payload, estimate in self?.handleCode(payload, estimate) }
        ar.onCamera = { [weak self] camera in self?.handleCamera(camera) }
        ar.onTracking = { [weak self] status in self?.tracking = status }
        ar.onError = { [weak self] message in self?.phase = .failed(message) }
        ar.scanningEnabled = !request.isDemo
        ar.start()
        if case .scanning = phase, !request.isDemo {
            speech.say(instructionTitle)
        }
    }

    func stop() {
        ar.onCodeDetected = nil
        ar.onCamera = nil
        ar.onTracking = nil
        ar.onError = nil
        ar.pause()
        speech.stop()
    }

    // MARK: Derived information for the UI

    var destinationName: String { building.location(request.destinationID)?.name ?? "your destination" }

    var currentLeg: RouteLeg? {
        guard let route, route.legs.indices.contains(legIndex) else { return nil }
        return route.legs[legIndex]
    }

    var nextStepIndex: Int? { status?.nextStepIndex }

    var isAligned: Bool { alignment != nil }

    var canAlignWithoutCode: Bool {
        guard route != nil else { return false }
        switch phase {
        case .scanning, .connector: return true
        case .navigating: return true
        default: return false
        }
    }

    var instructionSymbol: String {
        switch phase {
        case .scanning: return request.isDemo ? "iphone.gen3.radiowaves.left.and.right" : "qrcode.viewfinder"
        case .navigating:
            if status?.offRoute == true { return "exclamationmark.triangle.fill" }
            if let i = nextStepIndex, steps.indices.contains(i) { return steps[i].symbol }
            return "arrow.up"
        case .connector:
            return currentLeg?.exitConnector?.kind.symbol ?? "arrow.up.arrow.down.square"
        case .arrived: return "flag.checkered"
        case .failed: return "exclamationmark.octagon"
        }
    }

    var instructionTitle: String {
        switch phase {
        case .scanning:
            if request.isDemo { return "Move your iPhone slowly" }
            if let start = building.location(currentLeg?.startID ?? startID) {
                return "Scan the sign at \(start.name)"
            }
            return "Scan the nearest NaviGatAR sign"
        case .navigating:
            if status?.offRoute == true { return "Head back to the path" }
            if let i = nextStepIndex, steps.indices.contains(i) { return steps[i].text }
            return "Follow the path"
        case .connector(let text): return text
        case .arrived: return "You have arrived"
        case .failed: return "Can't show directions"
        }
    }

    var instructionDetail: String {
        switch phase {
        case .scanning:
            if request.isDemo { return "The demo path appears as soon as AR is ready." }
            return "Point the camera at the QR code and hold steady for a moment."
        case .navigating:
            guard let status else { return "Walk toward the first marker." }
            if status.offRoute { return "You're \(settings.distance(status.lateral)) from the route." }
            let remaining = "\(settings.distance(status.remaining)) to go"
            if status.distanceToNextStep < 1.5 { return "Now · \(remaining)" }
            return "In \(settings.distance(status.distanceToNextStep)) · \(remaining)"
        case .connector:
            let next = currentLeg?.exitConnector.flatMap { building.location($0.toID)?.name } ?? "the next sign"
            return "Then scan the sign at \(next) to continue."
        case .arrived: return destinationName
        case .failed(let message): return message
        }
    }

    var legProgressText: String? {
        guard let route, route.legs.count > 1 else { return nil }
        return "Part \(legIndex + 1) of \(route.legs.count)"
    }

    // MARK: Actions

    /// Places the path assuming the visitor stands in front of the expected
    /// sign, facing it. Less accurate than scanning, but always possible.
    func alignWithoutCode() {
        guard let route else { return }
        guard let camera = ar.latestCamera, ar.tracking == .normal else {
            flash("Move your iPhone slowly until AR is ready, then try again.")
            return
        }
        var target = legIndex
        if case .connector = phase { target = min(legIndex + 1, route.legs.count - 1) }
        align(legIndex: target, signPoseInLeg: .identity,
              observed: .estimatedAnchor(cameraPosition: camera.position, cameraForward: camera.forward))
        flash("Path placed approximately. Scan a sign when you pass one for better accuracy.")
    }

    /// Skips ahead after a connector when there is no sign to scan.
    func continueAfterConnector() {
        guard let route, case .connector = phase else { return }
        let next = legIndex + 1
        guard route.legs.indices.contains(next) else { arrive(); return }
        if route.legs[next].points.count < 2 && next == route.legs.count - 1 {
            legIndex = next
            arrive()
            return
        }
        loadLeg(next)
        alignment = nil
        ar.renderer.setVisible(false)
        phase = .scanning
        speech.say(instructionTitle)
    }

    // MARK: Event handling

    private func handleCode(_ payload: String, _ estimate: QRAnchorEstimator.Estimate) {
        guard let code = QRPayload(string: payload) else { return }
        guard code.buildingID == building.id, let location = building.location(code.locationID) else {
            flash("That code isn't a sign for \(building.name).")
            return
        }
        if case .arrived = phase { return }
        if case .failed = phase, route == nil { return }
        if let last = lastAlignment[location.id], Date().timeIntervalSince(last) < 4 { return }
        lastAlignment[location.id] = Date()

        if let route, let leg = route.legIndex(containing: location.id, startingAt: legIndex),
           let signPose = route.legs[leg].nodePoses[location.id] {
            // While riding the elevator etc. only signs further along count.
            if case .connector = phase, leg <= legIndex { return }
            let firstAlignment = alignment == nil
            align(legIndex: leg, signPoseInLeg: signPose, observed: estimate.pose)
            let suffix = estimate.quality == .precise ? "" : " (approximate)"
            flash(firstAlignment ? "Found \(location.name)\(suffix). Follow the path!" : "Re-aligned at \(location.name)\(suffix)")
            if firstAlignment { speech.say("Found \(location.name). Follow the path.") }
            return
        }

        // A sign that isn't on the planned route: start (again) from there.
        guard let plan = makePlan(from: location.id) else {
            if route == nil { phase = .failed(noRouteMessage(from: location.id)) }
            else { flash("No route from \(location.name). Keep following the path.") }
            return
        }
        let rerouting = route != nil
        adopt(plan)
        align(legIndex: 0, signPoseInLeg: .identity, observed: estimate.pose)
        flash(rerouting ? "New route from \(location.name)" : "Starting at \(location.name)")
        speech.say(rerouting ? "New route from \(location.name)." : "Starting at \(location.name). Follow the path.")
    }

    private func handleCamera(_ camera: CameraSample) {
        if request.isDemo, alignment == nil, ar.tracking == .normal, route != nil {
            align(legIndex: 0, signPoseInLeg: .identity,
                  observed: .estimatedAnchor(cameraPosition: camera.position, cameraForward: camera.forward))
            speech.say("Follow the path.")
        }
        guard let alignment, var tracker = self.tracker else { return }
        let toLeg = alignment.inverse()
        let local = toLeg.apply(camera.position)
        userPosition = local
        userHeading = toLeg.rotate(camera.forward)

        guard case .navigating = phase, ar.tracking == .normal else { return }
        let newStatus = tracker.update(position: local)
        self.tracker = tracker
        status = newStatus
        if abs(newStatus.arc - lastRenderedArc) > 0.25 {
            ar.renderer.updateVisibility(progress: newStatus.arc)
            lastRenderedArc = newStatus.arc
        }
        announce(newStatus)
        if newStatus.reachedEnd { finishLeg() }
    }

    // MARK: Route handling

    private func makePlan(from start: UUID) -> PlannedRoute? {
        RoutePlanner.plan(in: building, from: start, to: request.destinationID, stepFreeOnly: request.stepFreeOnly)
    }

    private func noRouteMessage(from start: UUID) -> String {
        let from = building.location(start)?.name ?? "here"
        if start == request.destinationID { return "You're already at \(destinationName)." }
        let kind = request.stepFreeOnly ? "step-free route" : "route"
        return "No \(kind) from \(from) to \(destinationName) has been recorded yet. Ask the building manager to add one."
    }

    private func adopt(_ plan: PlannedRoute) {
        route = plan
        startID = plan.startID
        alignment = nil
        announced.removeAll()
        phase = .scanning
        loadLeg(0)
        ar.renderer.setVisible(false)
    }

    private func loadLeg(_ index: Int) {
        guard let route, route.legs.indices.contains(index) else { return }
        legIndex = index
        let leg = route.legs[index]
        let finalText: String
        if let connector = leg.exitConnector {
            finalText = RoutePlanner.connectorText(connector, in: building)
        } else {
            finalText = "Arrive at \(destinationName)"
        }
        steps = DirectionsBuilder.steps(points: leg.points, notes: leg.notes, finalText: finalText,
                                        finalIsConnector: leg.exitConnector != nil)
        tracker = LegTracker(points: leg.points, steps: steps)
        status = nil
        lastRenderedArc = -100
        let label = leg.exitConnector == nil ? destinationName : building.location(leg.endID)?.name
        ar.renderer.showPath(points: leg.points, notes: leg.notes, signs: Array(leg.nodePoses.values),
                             destinationLabel: label, settings: settings)
    }

    private func align(legIndex index: Int, signPoseInLeg: Pose, observed: Pose) {
        if index != legIndex || tracker == nil { loadLeg(index) }
        let newAlignment = observed * signPoseInLeg.inverse()
        alignment = newAlignment
        ar.renderer.setAlignment(newAlignment)
        ar.renderer.setVisible(true)
        if case .arrived = phase { return }
        phase = .navigating
    }

    private func finishLeg() {
        guard let route, let leg = currentLeg else { return }
        if let connector = leg.exitConnector, legIndex + 1 < route.legs.count {
            let text = RoutePlanner.connectorText(connector, in: building)
            let next = building.location(connector.toID)?.name ?? "the next sign"
            phase = .connector(text)
            ar.renderer.setVisible(false)
            speech.say("\(text). Then scan the sign at \(next).")
        } else {
            arrive()
        }
    }

    private func arrive() {
        phase = .arrived
        speech.say("You have arrived at \(destinationName).")
    }

    private func announce(_ status: LegTracker.Status) {
        if status.offRoute {
            if Date().timeIntervalSince(lastOffRouteWarning) > 15 {
                lastOffRouteWarning = Date()
                speech.say("You're off the route. Head back to the path.")
            }
            return
        }
        guard let i = status.nextStepIndex, steps.indices.contains(i) else { return }
        let step = steps[i]
        // Arrival and connectors are announced when the leg ends.
        guard step.kind != .arrive, step.kind != .connector else { return }
        let key = "\(legIndex)-\(step.id)"
        let distance = status.distanceToNextStep
        if !announced.contains("first-\(key)") {
            announced.insert("first-\(key)")
            if distance > 5 {
                let inDistance = "In \(DistanceText.spoken(distance, imperial: settings.imperial))"
                speech.say(step.kind == .note ? "\(inDistance): \(step.text)" : "\(inDistance), \(step.text.lowercased()).")
            } else {
                announced.insert("near-\(key)")
                speech.say(step.text)
            }
        } else if distance <= 3, !announced.contains("near-\(key)") {
            announced.insert("near-\(key)")
            speech.say(step.kind == .note ? step.text : "\(step.text) now.")
        }
    }

    private func flash(_ message: String) {
        banner = message
        bannerToken += 1
        let token = bannerToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
        }
    }
}
