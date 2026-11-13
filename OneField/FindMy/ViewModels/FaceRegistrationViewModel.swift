//
//  FaceRegistrationViewModel.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//
import SwiftUI
import AVFoundation
import Vision
import Combine

class FaceRegistrationViewModel: NSObject, ObservableObject {
    @Published var isCapturing = false
    @Published var capturedFaces: [VNFaceObservation] = []
    @Published var capturedPhotos: [UIImage] = []
    @Published var detectedFaceCount = 0
    @Published var message = "Posiciona tu cara en el centro"
    
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    
    private let faceRecognitionManager: FaceRecognitionManager
    private var captureCount = 0
    private let maxCaptures = 5
    
    init(faceRecognitionManager: FaceRecognitionManager) {
        self.faceRecognitionManager = faceRecognitionManager
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ),
        let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "video.queue")
        )
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }
    
    func startCapture() {
        isCapturing = true
        captureCount = 0
        capturedFaces.removeAll()
        capturedPhotos.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopCapture() {
        isCapturing = false
        captureSession.stopRunning()
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func registerPerson(name: String) -> Bool {
        guard !capturedFaces.isEmpty, !name.isEmpty else {
            return false
        }
        
        let person = faceRecognitionManager.registerNewPerson(
            name: name,
            from: capturedFaces,
            photos: capturedPhotos
        )
        
        return person != nil
    }
    
    private func detectFaceInFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let observations = request.results as? [VNFaceObservation],
                  let face = observations.first else {
                DispatchQueue.main.async {
                    self?.detectedFaceCount = 0
                    self?.message = "No se detecta ninguna cara"
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.detectedFaceCount = observations.count
                
                if observations.count == 1 {
                    self?.message = "✓ Cara detectada - Toca para capturar"
                } else {
                    self?.message = "Solo debe haber una persona"
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

extension FaceRegistrationViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isCapturing else { return }
        detectFaceInFrame(sampleBuffer)
    }
}

extension FaceRegistrationViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData),
              let pixelBuffer = image.pixelBuffer() else {
            return
        }
        
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let observations = request.results as? [VNFaceObservation],
                  let face = observations.first else {
                return
            }
            
            DispatchQueue.main.async {
                self?.capturedFaces.append(face)
                self?.capturedPhotos.append(image)
                self?.captureCount += 1
                
                if self?.captureCount ?? 0 >= self?.maxCaptures ?? 5 {
                    self?.message = "✓ Capturas completadas"
                    self?.stopCapture()
                } else {
                    self?.message = "Captura \(self?.captureCount ?? 0)/\(self?.maxCaptures ?? 5) - Cambia el ángulo"
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
