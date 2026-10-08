import ARKit
import RealityKit
import UIKit
import Vision

/// Camera pose taken from an ARFrame.
struct CameraSample {
    var position: Vec3
    /// Direction the back camera is looking.
    var forward: Vec3

    init(transform t: simd_float4x4) {
        position = Vec3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        forward = -Vec3(t.columns.2.x, t.columns.2.y, t.columns.2.z)
    }
}

enum TrackingStatus: Equatable {
    case normal
    case limited(String)
    case unavailable

    init(_ state: ARCamera.TrackingState) {
        switch state {
        case .normal:
            self = .normal
        case .notAvailable:
            self = .unavailable
        case .limited(let reason):
            switch reason {
            case .initializing: self = .limited("Move your iPhone slowly to start AR")
            case .excessiveMotion: self = .limited("Slow down a little")
            case .insufficientFeatures: self = .limited("Point at a more detailed area or add light")
            case .relocalizing: self = .limited("Recovering tracking…")
            @unknown default: self = .limited("AR tracking is limited")
            }
        @unknown default:
            self = .unavailable
        }
    }

    var message: String? {
        switch self {
        case .normal: return nil
        case .limited(let text): return text
        case .unavailable: return "Starting the camera…"
        }
    }
}

/// Owns the ARView/ARSession, finds NaviGatAR QR signs in the camera feed and
/// reports where they are in AR world space.
///
/// ARSession delivers delegate callbacks on the main queue, so all state here
/// is only touched from the main thread (Vision runs on a private queue and
/// hops back to main with its results).
final class ARSessionController: NSObject, ARSessionDelegate {
    static var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    let arView: ARView
    let renderer = PathRenderer()

    /// Set to false to stop looking for QR codes (saves battery).
    var scanningEnabled = true
    var onCodeDetected: ((String, QRAnchorEstimator.Estimate) -> Void)?
    var onCamera: ((CameraSample) -> Void)?
    var onTracking: ((TrackingStatus) -> Void)?
    var onError: ((String) -> Void)?

    private(set) var latestCamera: CameraSample?
    private(set) var tracking: TrackingStatus = .unavailable

    private let visionQueue = DispatchQueue(label: "navigatar.qr-detection", qos: .userInitiated)
    private var scanInFlight = false
    private var lastScanTime: TimeInterval = 0
    private var lastCameraCallback: TimeInterval = 0
    private var accumulator = AnchorSampleAccumulator()
    private var isRunning = false

    override init() {
        arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        super.init()
        arView.session.delegate = self
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)
        renderer.attach(to: arView)

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .tracking
        coaching.activatesAutomatically = true
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coaching)
    }

    func start() {
        guard Self.isSupported, !isRunning else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        accumulator.reset()
        isRunning = true
    }

    func pause() {
        guard isRunning else { return }
        arView.session.pause()
        isRunning = false
    }

    func resetDetections() { accumulator.reset() }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let camera = CameraSample(transform: frame.camera.transform)
        latestCamera = camera

        let status = TrackingStatus(frame.camera.trackingState)
        if status != tracking {
            tracking = status
            onTracking?(status)
        }
        if frame.timestamp - lastCameraCallback >= 0.1 {
            lastCameraCallback = frame.timestamp
            onCamera?(camera)
        }

        guard scanningEnabled, status == .normal, !scanInFlight,
              frame.timestamp - lastScanTime >= 0.2 else { return }
        scanInFlight = true
        lastScanTime = frame.timestamp
        detectCodes(in: frame)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        isRunning = false
        if let arError = error as? ARError, arError.code == .cameraUnauthorized {
            onError?("NaviGatAR needs the camera to show directions. Turn it on in Settings › NaviGatAR › Camera.")
        } else {
            onError?(error.localizedDescription)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        onTracking?(.limited("AR paused"))
    }

    // MARK: QR detection

    private func detectCodes(in frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        visionQueue.async { [weak self] in
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            // `.up` keeps Vision's coordinates in the raw camera image space,
            // which is what ARFrame.raycastQuery expects.
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try? handler.perform([request])
            let observations = (request.results ?? []).filter { $0.payloadStringValue != nil }
            DispatchQueue.main.async {
                guard let self else { return }
                self.scanInFlight = false
                for observation in observations { self.locate(observation, in: frame) }
            }
        }
    }

    private func locate(_ observation: VNBarcodeObservation, in frame: ARFrame) {
        guard let payload = observation.payloadStringValue else { return }
        let camera = CameraSample(transform: frame.camera.transform)
        let corners = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
            .map { raycast($0, in: frame)?.position }
        let box = observation.boundingBox
        let center = raycast(CGPoint(x: box.midX, y: box.midY), in: frame)
        let estimate = QRAnchorEstimator.estimate(cornerHits: corners, centerHit: center?.position,
                                                  centerNormal: center?.normal,
                                                  cameraPosition: camera.position, cameraForward: camera.forward)
        if let averaged = accumulator.add(payload: payload, estimate: estimate, time: frame.timestamp) {
            onCodeDetected?(payload, averaged)
        }
    }

    /// Raycasts from a Vision point (normalised, origin bottom-left) onto real surfaces.
    private func raycast(_ visionPoint: CGPoint, in frame: ARFrame) -> (position: Vec3, normal: Vec3)? {
        let imagePoint = CGPoint(x: visionPoint.x, y: 1 - visionPoint.y)
        let query = frame.raycastQuery(from: imagePoint, allowing: .estimatedPlane, alignment: .any)
        guard let result = arView.session.raycast(query).first else { return nil }
        let t = result.worldTransform
        return (Vec3(t.columns.3.x, t.columns.3.y, t.columns.3.z),
                Vec3(t.columns.1.x, t.columns.1.y, t.columns.1.z))
    }
}
