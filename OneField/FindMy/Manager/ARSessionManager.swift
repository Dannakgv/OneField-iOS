//
//  ARSessionManager.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//

import ARKit
import RealityKit
import Combine

class ARSessionManager: NSObject, ObservableObject {
    var objectWillChange = ObservableObjectPublisher()

    @Published var currentFrame: ARFrame?
    
    private let arView: ARView
    private let session = ARSession()
    
    init(arView: ARView) {
        self.arView = arView
        super.init()
        setupARSession()
    }
    
    private func setupARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            configuration.frameSemantics = .personSegmentation
        }
        
        arView.session = session
        session.delegate = self
        session.run(configuration)
    }
    
    func pause() {
        session.pause()
    }
    
    func resume() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration)
    }
    
    func worldPosition(for point2D: CGPoint, in frame: ARFrame) -> simd_float3? {
        let imageResolution = frame.camera.imageResolution
        
        let normalizedPoint = CGPoint(
            x: point2D.x / imageResolution.width,
            y: point2D.y / imageResolution.height
        )
        
        let viewportSize = arView.bounds.size
        let screenPoint = CGPoint(
            x: normalizedPoint.x * viewportSize.width,
            y: (1 - normalizedPoint.y) * viewportSize.height
        )
        
        let results = arView.raycast(
            from: screenPoint,
            allowing: .estimatedPlane,
            alignment: .any
        )
        
        if let firstResult = results.first {
            let position = firstResult.worldTransform.columns.3
            return simd_float3(position.x, position.y, position.z)
        }
        
        return estimateWorldPosition(for: normalizedPoint, frame: frame)
    }
    
    private func estimateWorldPosition(for normalizedPoint: CGPoint, frame: ARFrame) -> simd_float3 {
        let camera = frame.camera
        let estimatedDepth: Float = 1.5
        
        let x = (Float(normalizedPoint.x) * 2.0 - 1.0) * estimatedDepth * 0.5
        let y = (Float(normalizedPoint.y) * 2.0 - 1.0) * estimatedDepth * 0.5
        
        let cameraPosition = camera.transform.columns.3
        let cameraForward = normalize(simd_float3(
            -camera.transform.columns.2.x,
            -camera.transform.columns.2.y,
            -camera.transform.columns.2.z
        ))
        
        let cameraRight = normalize(simd_float3(
            camera.transform.columns.0.x,
            camera.transform.columns.0.y,
            camera.transform.columns.0.z
        ))
        
        let cameraUp = normalize(simd_float3(
            camera.transform.columns.1.x,
            camera.transform.columns.1.y,
            camera.transform.columns.1.z
        ))
        
        return simd_float3(
            cameraPosition.x + cameraForward.x * estimatedDepth + cameraRight.x * x + cameraUp.x * y,
            cameraPosition.y + cameraForward.y * estimatedDepth + cameraRight.y * x + cameraUp.y * y,
            cameraPosition.z + cameraForward.z * estimatedDepth + cameraRight.z * x + cameraUp.z * y
        )
    }
}

extension ARSessionManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            self.currentFrame = frame
        }
    }
}
