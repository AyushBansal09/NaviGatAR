import RealityKit
import SwiftUI

/// Hosts the controller's ARView inside SwiftUI.
struct ARViewContainer: UIViewRepresentable {
    let controller: ARSessionController

    func makeUIView(context: Context) -> ARView { controller.arView }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
