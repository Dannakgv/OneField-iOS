//
//  ARViewContainer.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//

import SwiftUI
import ARKit
import RealityKit

// MARK: - AR View Container

struct FindMyARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARGuidanceViewModel
    var faceRecognitionManager: FaceRecognitionManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        
        // Pasar el ARView al ViewModel
        viewModel.setup(arView: arView, faceRecognitionManager: faceRecognitionManager)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
    }
}
