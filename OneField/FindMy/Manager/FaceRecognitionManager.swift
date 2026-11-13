import Vision
import UIKit
import Combine
import RealityKit

class FaceRecognitionManager: ObservableObject {
    @Published var recognizedFaces: [UUID: KnownPerson] = [:]
    
    private var knownPeople: [KnownPerson] = []
    private let threshold: Float = 0.6
    private let processingQueue = DispatchQueue(label: "face.recognition.queue", qos: .userInitiated)
    private var faceTracking: [UUID: Date] = [:] // Track del tiempo de reconocimiento
    
    init() {
        loadKnownPeople()
    }
    
    private func loadKnownPeople() {
        if let people = FaceStorageManager.shared.loadAllPeople() {
            self.knownPeople = people
            print("✅ Cargadas \(people.count) personas para reconocimiento")
        }
    }
    
    func recognizeFaces(in pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedFace]) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self else {
                completion([])
                return
            }
            
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard let observations = request.results as? [VNFaceObservation] else {
                    completion([])
                    return
                }
                self.processFaceObservations(observations, in: pixelBuffer, completion: completion)
            }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("❌ Error en detección de caras: \(error)")
                completion([])
            }
        }
    }
    
    private func processFaceObservations(_ observations: [VNFaceObservation], in pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedFace]) -> Void) {
        var detectedFaces: [DetectedFace] = []
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            completion([])
            return
        }
        
        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        
        for observation in observations {
            dispatchGroup.enter()
            
            self.extractFaceDescriptor(from: observation, cgImage: cgImage) { descriptor in
                defer { dispatchGroup.leave() }
                
                guard let descriptor = descriptor else {
                    let face = self.makeDetectedFace(from: observation, personId: nil)
                    lock.lock()
                    detectedFaces.append(face)
                    lock.unlock()
                    return
                }
                
                let matchedPerson = self.findMatch(for: descriptor)
                let face = self.makeDetectedFace(from: observation, personId: matchedPerson?.id)
                
                lock.lock()
                detectedFaces.append(face)
                
                if let matchedPerson = matchedPerson {
                    let faceId = face.id
                    let now = Date()
                    
                    // Solo actualizar si ha pasado suficiente tiempo o es nuevo reconocimiento
                    if let lastRecognition = self.faceTracking[faceId] {
                        // Actualizar máximo cada 3 segundos para evitar flickering
                        if now.timeIntervalSince(lastRecognition) > 3.0 {
                            DispatchQueue.main.async {
                                self.recognizedFaces[faceId] = matchedPerson
                                self.updatePersonStatistics(matchedPerson)
                            }
                            self.faceTracking[faceId] = now
                        }
                    } else {
                        // Nuevo reconocimiento
                        DispatchQueue.main.async {
                            self.recognizedFaces[faceId] = matchedPerson
                            self.updatePersonStatistics(matchedPerson)
                        }
                        self.faceTracking[faceId] = now
                    }
                }
                lock.unlock()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // Limpiar caras que ya no están siendo trackeadas
            self.cleanupOldFaces(currentFaceIds: Set(detectedFaces.map { $0.id }))
            completion(detectedFaces)
        }
    }
    
    private func cleanupOldFaces(currentFaceIds: Set<UUID>) {
        let now = Date()
        let idsToRemove = faceTracking.keys.filter { !currentFaceIds.contains($0) }
        
        for id in idsToRemove {
            faceTracking.removeValue(forKey: id)
            DispatchQueue.main.async {
                self.recognizedFaces.removeValue(forKey: id)
            }
        }
        
        // También limpiar reconocimientos muy viejos (por seguridad)
        let oldThreshold: TimeInterval = 8.0 // 8 segundos
        for (faceId, lastSeen) in faceTracking {
            if now.timeIntervalSince(lastSeen) > oldThreshold {
                faceTracking.removeValue(forKey: faceId)
                DispatchQueue.main.async {
                    self.recognizedFaces.removeValue(forKey: faceId)
                }
            }
        }
    }
    
    private func extractFaceDescriptor(from observation: VNFaceObservation, cgImage: CGImage, completion: @escaping (FaceEmbedding?) -> Void) {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // Convertir boundingBox de coordenadas normalizadas a píxeles
        let bbox = observation.boundingBox
        let cropRect = CGRect(
            x: bbox.origin.x * imageWidth,
            y: (1.0 - bbox.origin.y - bbox.height) * imageHeight,
            width: bbox.width * imageWidth,
            height: bbox.height * imageHeight
        ).integral
        
        // Asegurar que el rectángulo esté dentro de los límites de la imagen
        guard cropRect.width > 0, cropRect.height > 0,
              cropRect.origin.x >= 0, cropRect.origin.y >= 0,
              cropRect.maxX <= imageWidth, cropRect.maxY <= imageHeight,
              let faceCgImage = cgImage.cropping(to: cropRect) else {
            completion(nil)
            return
        }
        
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision1
        
        let handler = VNImageRequestHandler(cgImage: faceCgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            if let featurePrint = request.results?.first as? VNFeaturePrintObservation {
                // Convertir VNFeaturePrintObservation a array de Float para comparación
                var descriptorArray = [Float](repeating: 0, count: featurePrint.elementCount)
                featurePrint.data.withUnsafeBytes { rawBufferPointer in
                    let bufferPointer = rawBufferPointer.bindMemory(to: Float.self)
                    for i in 0..<min(featurePrint.elementCount, bufferPointer.count) {
                        descriptorArray[i] = bufferPointer[i]
                    }
                }
                
                let embedding = FaceEmbedding(descriptor: descriptorArray, personId: UUID())
                completion(embedding)
            } else {
                completion(nil)
            }
        } catch {
            print("❌ Error extrayendo descriptor facial: \(error)")
            completion(nil)
        }
    }
    
    private func makeDetectedFace(from observation: VNFaceObservation, personId: UUID?) -> DetectedFace {
        return DetectedFace(
            boundingBox: observation.boundingBox,
            worldPosition: nil,
            distance: nil,
            confidence: observation.confidence,
            timestamp: Date()
        )
    }
    
    private func findMatch(for embedding: FaceEmbedding) -> KnownPerson? {
        var bestMatch: (person: KnownPerson, similarity: Float)? = nil
        
        for person in knownPeople {
            for descriptorData in person.faceDescriptors {
                // Convertir Data de vuelta a array de Float
                var descriptorArray = [Float](repeating: 0, count: descriptorData.count / MemoryLayout<Float>.size)
                _ = descriptorArray.withUnsafeMutableBytes { mutableRawBufferPointer in
                    descriptorData.copyBytes(to: mutableRawBufferPointer)
                }
                
                let knownEmbedding = FaceEmbedding(descriptor: descriptorArray, personId: person.id)
                let similarity = embedding.similarity(to: knownEmbedding)
                
                print("🔍 Comparando con \(person.name): similitud = \(similarity)")
                
                if similarity > threshold {
                    if let currentBest = bestMatch {
                        if similarity > currentBest.similarity {
                            bestMatch = (person, similarity)
                        }
                    } else {
                        bestMatch = (person, similarity)
                    }
                }
            }
        }
        
        if let best = bestMatch {
            print("✅ Reconocido: \(best.person.name) con similitud \(best.similarity)")
        } else {
            print("❌ No se reconoció a nadie (mejor similitud: \(bestMatch?.similarity ?? 0))")
        }
        
        return bestMatch?.person
    }
    
    private func updatePersonStatistics(_ person: KnownPerson) {
        guard let index = knownPeople.firstIndex(where: { $0.id == person.id }) else { return }
        knownPeople[index].lastSeen = Date()
        knownPeople[index].timesDetected += 1
        FaceStorageManager.shared.updatePerson(knownPeople[index])
    }
    
    func registerNewPerson(name: String, from observations: [VNFaceObservation], photos: [UIImage]) -> KnownPerson? {
        guard let sampleImage = photos.first?.cgImage else { return nil }
        
        var descriptors: [Data] = []
        
        for observation in observations {
            if let descriptorData = extractFaceDescriptorData(from: observation, cgImage: sampleImage) {
                descriptors.append(descriptorData)
            }
        }
        
        guard !descriptors.isEmpty else { return nil }
        
        let photoData = photos.compactMap { $0.jpegData(compressionQuality: 0.7) }
        let person = KnownPerson(name: name, faceDescriptors: descriptors, photos: photoData)
        
        knownPeople.append(person)
        FaceStorageManager.shared.savePerson(person)
        
        print("✅ Nueva persona registrada: \(name) con \(descriptors.count) descriptores")
        return person
    }
    
    private func extractFaceDescriptorData(from observation: VNFaceObservation, cgImage: CGImage) -> Data? {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        let bbox = observation.boundingBox
        let cropRect = CGRect(
            x: bbox.origin.x * imageWidth,
            y: (1.0 - bbox.origin.y - bbox.height) * imageHeight,
            width: bbox.width * imageWidth,
            height: bbox.height * imageHeight
        ).integral
        
        guard cropRect.width > 0, cropRect.height > 0,
              cropRect.origin.x >= 0, cropRect.origin.y >= 0,
              cropRect.maxX <= imageWidth, cropRect.maxY <= imageHeight,
              let faceCgImage = cgImage.cropping(to: cropRect) else {
            return nil
        }
        
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision1
        
        let handler = VNImageRequestHandler(cgImage: faceCgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            if let featurePrint = request.results?.first as? VNFeaturePrintObservation {
                // Guardar el descriptor completo como Data
                return featurePrint.data
            }
        } catch {
            print("❌ Error extrayendo descriptor para registro: \(error)")
        }
        
        return nil
    }
    
    func removePerson(_ person: KnownPerson) {
        knownPeople.removeAll { $0.id == person.id }
        recognizedFaces.removeValue(forKey: person.id)
        FaceStorageManager.shared.deletePerson(person)
    }
    
    func getKnownPeople() -> [KnownPerson] { return knownPeople }
    
    func reloadKnownPeople() {
        loadKnownPeople()
    }
}
