import SwiftUI
import ARKit
import Combine
import RealityKit
import AVFoundation

class ARGuidanceViewModel: ObservableObject {
    @Published var isTracking = false
    @Published var detectedFaceCount = 0
    @Published var statusMessage = "Mueve la cámara para detectar caras"
    @Published var voiceInstructionsEnabled = true
    @Published var currentInstruction = ""
    
    private var arSessionManager: ARSessionManager?
    private let faceDetectionManager = FaceDetectionManager()
    private var faceRecognitionManager: FaceRecognitionManager?
    private var arrowRenderer: ArrowRenderer?
    
    private var cancellables = Set<AnyCancellable>()
    private var processingTimer: Timer?
    
    func setup(arView: ARView, faceRecognitionManager: FaceRecognitionManager) {
        self.faceRecognitionManager = faceRecognitionManager
        arSessionManager = ARSessionManager(arView: arView)
        
        // Inicializar el nuevo ArrowRenderer con ARView
        arrowRenderer = ArrowRenderer(arView: arView)
        
        setupBindings()
        startProcessing()
        
        // Probar instrucciones de voz después de 2 segundos
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.arrowRenderer?.testVoiceInstructions()
        }
    }
    
    private func setupBindings() {
        faceDetectionManager.$detectedFaces
            .receive(on: DispatchQueue.main)
            .sink { [weak self] faces in
                self?.detectedFaceCount = faces.count
                self?.updateStatusMessage(faceCount: faces.count)
            }
            .store(in: &cancellables)
    }
    
    private func startProcessing() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.processCurrentFrame()
        }
    }
    
    private func processCurrentFrame() {
        guard let frame = arSessionManager?.currentFrame,
              let recognitionManager = faceRecognitionManager,
              let arrowRenderer = arrowRenderer else {
            return
        }
        
        recognitionManager.recognizeFaces(in: frame.capturedImage) { [weak self] detectedFaces in
            guard let self = self else { return }
            
            var updatedFaces: [DetectedFace] = []
            
            for face in detectedFaces {
                let centerPoint = CGPoint(
                    x: face.boundingBox.midX * frame.camera.imageResolution.width,
                    y: (1 - face.boundingBox.midY) * frame.camera.imageResolution.height
                )
                
                if let worldPos = self.arSessionManager?.worldPosition(for: centerPoint, in: frame) {
                    let cameraPos = simd_float3(
                        frame.camera.transform.columns.3.x,
                        frame.camera.transform.columns.3.y,
                        frame.camera.transform.columns.3.z
                    )
                    
                    let distance = simd_distance(worldPos, cameraPos)
                    
                    var updatedFace = face
                    updatedFace.worldPosition = worldPos
                    updatedFace.distance = distance
                    
                    updatedFaces.append(updatedFace)
                }
            }
            
            // Actualizar el contador de caras detectadas
            DispatchQueue.main.async {
                self.detectedFaceCount = updatedFaces.count
                self.updateStatusMessage(faceCount: updatedFaces.count)
            }
            
            // Pasar las caras actualizadas al ArrowRenderer
            arrowRenderer.updateArrowsWithNames(
                for: updatedFaces,
                recognizedFaces: recognitionManager.recognizedFaces,
                cameraTransform: frame.camera.transform
            )
            
            self.faceDetectionManager.cleanOldDetections()
        }
    }
    
    private func updateStatusMessage(faceCount: Int) {
        switch faceCount {
        case 0:
            statusMessage = "Buscando personas..."
        case 1:
            statusMessage = "1 persona detectada"
        default:
            statusMessage = "\(faceCount) personas detectadas"
        }
    }
    
    func toggleTracking() {
        isTracking.toggle()
        
        if isTracking {
            arSessionManager?.resume()
            statusMessage = "Seguimiento activado"
        } else {
            arSessionManager?.pause()
            arrowRenderer?.removeAllArrows()
            statusMessage = "Seguimiento pausado"
        }
    }
    
    func toggleVoiceInstructions() {
        voiceInstructionsEnabled.toggle()
        
        if voiceInstructionsEnabled {
            arrowRenderer?.testVoiceInstructions()
            statusMessage = "Instrucciones de voz activadas"
        } else {
            arrowRenderer?.stopVoiceGuidance()
            statusMessage = "Instrucciones de voz desactivadas"
        }
    }
    
    // Método para probar la flecha
    func testArrow() {
        arrowRenderer?.addTestArrow()
    }
    
    deinit {
        processingTimer?.invalidate()
        arrowRenderer?.removeAllArrows()
        arrowRenderer?.stopUpdating()
    }
}
