//
//  KnownPerson.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//
import Vision
import UIKit

struct KnownPerson: Identifiable, Codable {
    let id: UUID
    var name: String
    var nickname: String?
    var faceDescriptors: [Data]  
    var captureDate: Date
    var lastSeen: Date?
    var timesDetected: Int
    var photos: [Data]
    
    init(name: String, faceDescriptors: [Data], photos: [Data] = []) {
        self.id = UUID()
        self.name = name
        self.faceDescriptors = faceDescriptors
        self.captureDate = Date()
        self.timesDetected = 0
        self.photos = photos
    }
}

extension VNFaceObservation {

    func faceDescriptorData(from cgImage: CGImage) -> Data? {
        // Dimensiones de la imagen
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // boundingBox está en coordenadas normalizadas (0..1).
        // En Vision el origen para boundingBox es (0,0) en la esquina **inferior izquierda**, así que convertimos:
        let bbox = self.boundingBox
        let cropRect = CGRect(
            x: bbox.origin.x * imageWidth,
            y: (1.0 - bbox.origin.y - bbox.height) * imageHeight,
            width: bbox.width * imageWidth,
            height: bbox.height * imageHeight
        ).integral
        
        guard let faceCg = cgImage.cropping(to: cropRect) else {
            // si el recorte falla, intenta usar la imagen completa o devuelve nil
            return nil
        }
        
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: faceCg, options: [:])
        
        do {
            // Ejecutar la petición (hazlo en background en producción)
            try handler.perform([request])
            guard let fp = request.results?.first as? VNFeaturePrintObservation else {
                return nil
            }
            // `fp.data` es un Data que contiene el feature-print — ideal para persistir.
            return fp.data
        } catch {
            print("Error generando feature print: \(error)")
            return nil
        }
    }
    
    func faceDescriptorData(from uiImage: UIImage) -> Data? {
        guard let cg = uiImage.cgImage else { return nil }
        return faceDescriptorData(from: cg)
    }
}

