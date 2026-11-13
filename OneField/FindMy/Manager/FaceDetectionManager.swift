//
//  FaceDetectionManager.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//

import Vision
import ARKit
import Combine

class FaceDetectionManager: ObservableObject {
    @Published var detectedFaces: [DetectedFace] = []
    
    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    private let processingQueue = DispatchQueue(label: "face.detection.queue")
    
    init() {
        setupFaceDetection()
    }
    
    private func setupFaceDetection() {
        faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let observations = request.results as? [VNFaceObservation] else {
                return
            }
            
            self?.processFaceObservations(observations)
        }
        
        faceDetectionRequest?.revision = VNDetectFaceRectanglesRequestRevision3
    }
    
    func detectFaces(in frame: ARFrame, arSessionManager: ARSessionManager) {
        let pixelBuffer = frame.capturedImage
        
        processingQueue.async { [weak self] in
            guard let request = self?.faceDetectionRequest else { return }
            
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .right,
                options: [:]
            )
            
            try? handler.perform([request])
        }
    }
    
    private func processFaceObservations(_ observations: [VNFaceObservation]) {
        let faces = observations.map { observation -> DetectedFace in
            DetectedFace(
                boundingBox: observation.boundingBox,
                worldPosition: nil,
                distance: nil,
                confidence: observation.confidence,
                timestamp: Date()
            )
        }
        
        DispatchQueue.main.async {
            self.detectedFaces = faces
        }
    }
    
    func cleanOldDetections() {
        let now = Date()
        detectedFaces.removeAll { face in
            now.timeIntervalSince(face.timestamp) > 1.0
        }
    }
}
