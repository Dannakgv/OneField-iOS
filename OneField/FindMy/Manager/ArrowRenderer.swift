

import RealityKit
import ARKit
import UIKit
import simd
import AVFoundation

class ArrowRenderer {
    private var arrowAnchor: AnchorEntity?
    private var arrowEntity: Entity?
    private var arView: ARView?
    private var displayLink: CADisplayLink?
    
    private var targetPosition: SIMD3<Float>?
    private var smoothingFactor: Float = 0.1
    private var currentFaceTargets: [UUID: SIMD3<Float>] = [:]
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastVoiceInstruction: String = ""
    private var lastInstructionTime: Date = Date.distantPast
    
    init(arView: ARView) {
        self.arView = arView
        setupArrow()
        startUpdating()
    }
    
    // MARK: - Arrow Setup
    
    private func setupArrow() {
        // Crear la ancla en la CÁMARA (siempre frente al usuario)
        let anchor = AnchorEntity(.camera)
        arView?.scene.addAnchor(anchor)
        arrowAnchor = anchor
        
        // Cargar el modelo de la flecha
        if let arrowEntity = loadArrowModel() {
            arrowEntity.scale = [0.15, 0.15, 0.15] // Escala adecuada
            arrowEntity.name = "navigationArrow"
            
            // Posicionar la flecha fija frente a la cámara (coordenadas locales de la cámara)
            arrowEntity.position = [0, 0, -1.0] // 1 metro frente a la cámara
            
            anchor.addChild(arrowEntity)
            self.arrowEntity = arrowEntity
            
            // Aplicar color personalizado
            applyColorToArrow(arrowEntity, color: UIColor(red: 0.13, green: 0.57, blue: 0.98, alpha: 1.0))
            print("Flecha de navegación cargada exitosamente")
            
            // Ocultar inicialmente
            arrowEntity.isEnabled = false
        } else {
            print("Error: No se pudo cargar el modelo de flecha")
            // Crear una flecha simple como fallback
            createSimpleArrow()
        }
    }
    
    /// Carga el modelo Arrow.usdz
    private func loadArrowModel() -> Entity? {
        do {
            let entity = try Entity.load(named: "Arrow")
            return entity
        } catch {
            print("Error al cargar Arrow.usdz: \(error)")
            return nil
        }
    }
    
    /// Crea una flecha simple como fallback
    private func createSimpleArrow() {
        guard let anchor = arrowAnchor else { return }
        
        let arrow = ModelEntity(
            mesh: .generateCone(height: 0.2, radius: 0.05),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        arrow.name = "simpleNavigationArrow"
        arrow.scale = [0.3, 0.3, 0.3]
        arrow.position = [0, 0, -1.0] // 1 metro frente a la cámara
        anchor.addChild(arrow)
        self.arrowEntity = arrow
    }
    
    // MARK: - Color y Material
    
    private func applyColorToArrow(_ entity: Entity, color: UIColor) {
        if let modelEntity = entity as? ModelEntity {
            var material = SimpleMaterial()
            material.color = .init(tint: color)
            material.metallic = .init(floatLiteral: 0.7)
            material.roughness = .init(floatLiteral: 0.3)
            modelEntity.model?.materials = [material]
        }
        
        // Aplicar recursivamente a hijos
        for child in entity.children {
            applyColorToArrow(child, color: color)
        }
    }
    
    // MARK: - Update Loop
    
    private func startUpdating() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateArrow))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @objc private func updateArrow() {
        guard let arView = arView,
              let arrow = arrowEntity,
              let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
        
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x,
                                          cameraTransform.columns.3.y,
                                          cameraTransform.columns.3.z)
        
        // Verificar si hay target
        guard let targetPos = targetPosition else {
            // No hay target, ocultar flecha
            if arrow.isEnabled {
                arrow.isEnabled = false
            }
            return
        }
        
        // Mostrar flecha si estaba oculta
        if !arrow.isEnabled {
            arrow.isEnabled = true
        }
        
        // Solo rotar la flecha para que apunte al objetivo
        rotateArrowToTarget(cameraTransform: cameraTransform, targetPosition: targetPos)
        
        // Actualizar apariencia basada en distancia
        let distance = length(targetPos - cameraPosition)
        updateArrowAppearance(arrow: arrow, distance: distance)
    }
    
    private func rotateArrowToTarget(cameraTransform: simd_float4x4, targetPosition: SIMD3<Float>) {
        guard let arrow = arrowEntity else { return }
        
        let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x,
                                          cameraTransform.columns.3.y,
                                          cameraTransform.columns.3.z)
        
        // Calcular dirección al objetivo desde la cámara
        let directionToTarget = normalize(targetPosition - cameraPosition)
        
        // Obtener vectores de dirección de la cámara
        let cameraForward = SIMD3<Float>(cameraTransform.columns.2.x,
                                        cameraTransform.columns.2.y,
                                        cameraTransform.columns.2.z) * -1
        
        let cameraRight = SIMD3<Float>(cameraTransform.columns.0.x,
                                      cameraTransform.columns.0.y,
                                      cameraTransform.columns.0.z)
        
        let cameraUp = SIMD3<Float>(cameraTransform.columns.1.x,
                                   cameraTransform.columns.1.y,
                                   cameraTransform.columns.1.z)
        
        // Proyectar la dirección al target en el plano horizontal (XZ)
        let directionHorizontal = normalize(SIMD3<Float>(directionToTarget.x, 0, directionToTarget.z))
        let cameraForwardHorizontal = normalize(SIMD3<Float>(cameraForward.x, 0, cameraForward.z))
        
        // Calcular el ángulo horizontal (yaw)
        let dotProductHorizontal = dot(directionHorizontal, cameraForwardHorizontal)
        let crossProductHorizontal = cross(cameraForwardHorizontal, directionHorizontal)
        
        var yawAngle = acos(max(-1.0, min(1.0, dotProductHorizontal)))
        
        // Determinar la dirección de la rotación
        if crossProductHorizontal.y < 0 {
            yawAngle = -yawAngle
        }
        
        // Calcular el ángulo vertical (pitch)
        let dotProductVertical = dot(directionToTarget, cameraForward)
        let pitchAngle = acos(max(-1.0, min(1.0, dotProductVertical))) - (Float.pi / 2)
        
        // Crear rotaciones
        let yawRotation = simd_quatf(angle: yawAngle, axis: [0, 1, 0])
        let pitchRotation = simd_quatf(angle: pitchAngle * 0.3, axis: [1, 0, 0]) // Suavizar pitch
        
        // Combinar rotaciones
        let combinedRotation = yawRotation * pitchRotation
        
        // Suavizar rotación
        let smoothedRotation = simd_slerp(arrow.orientation, combinedRotation, smoothingFactor)
        arrow.orientation = smoothedRotation
        
        // DEBUG: Información de diagnóstico
        print("Flecha - Yaw: \(yawAngle * 180/Float.pi)°, Pitch: \(pitchAngle * 180/Float.pi)°")
    }
    
    private func updateArrowAppearance(arrow: Entity, distance: Float) {
        let scale: Float
        let color: UIColor
        
        if distance < 1.5 {
            scale = 0.2
            color = UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0) // Rojo - Muy cerca
        } else if distance < 3.0 {
            scale = 0.18
            color = UIColor(red: 0.13, green: 0.57, blue: 0.98, alpha: 1.0) // Azul - Medio
        } else if distance < 5.0 {
            scale = 0.16
            color = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0) // Verde - Lejos
        } else {
            scale = 0.14
            color = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) // Gris - Muy lejos
        }
        
        // Aplicar escala suavizada
        let currentScale = arrow.scale
        let newScale = SIMD3<Float>(scale, scale, scale)
        arrow.scale = mix(currentScale, newScale, t: 0.2)
        
        applyColorToArrow(arrow, color: color)
        
        // Efecto de pulso cuando está muy cerca
        if distance < 1.0 {
            let pulseScale = scale * (1.0 + 0.1 * sin(Float(Date().timeIntervalSince1970) * 3.0))
            arrow.scale = [pulseScale, pulseScale, pulseScale]
        }
    }
    
    // MARK: - Face Tracking
    
    func updateArrowsWithNames(for faces: [DetectedFace],
                               recognizedFaces: [UUID: KnownPerson],
                               cameraTransform: simd_float4x4) {
        
        let currentFaceIds = Set(faces.map { $0.id })
        
        // Limpiar targets de caras que ya no están
        let idsToRemove = currentFaceTargets.keys.filter { !currentFaceIds.contains($0) }
        for id in idsToRemove {
            currentFaceTargets.removeValue(forKey: id)
        }
        
        var closestFace: DetectedFace?
        var closestDistance: Float = Float.greatestFiniteMagnitude
        var closestTarget: SIMD3<Float>?
        
        for face in faces {
            guard let targetWorldPos = face.worldPosition else { continue }
            
            let cameraPos = simd_make_float3(cameraTransform.columns.3)
            let distance = simd_distance(targetWorldPos, cameraPos)
            
            // Actualizar posición objetivo
            currentFaceTargets[face.id] = targetWorldPos
            
            // Seguimiento de la cara más cercana
            if distance < closestDistance {
                closestDistance = distance
                closestFace = face
                closestTarget = targetWorldPos
            }
        }
        
        // Actualizar objetivo principal para la flecha
        if let closestTarget = closestTarget {
            setTarget(closestTarget)
            
            // Guía de voz
            if let closestFace = closestFace,
               let recognizedPerson = recognizedFaces[closestFace.id] {
                provideVoiceGuidance(
                    for: recognizedPerson,
                    distance: closestDistance,
                    cameraTransform: cameraTransform,
                    facePosition: closestFace.worldPosition
                )
            }
        } else {
            // Sin caras detectadas, quitar target
            clearTarget()
        }
    }
    
    func setTarget(_ position: SIMD3<Float>) {
        targetPosition = position
        print("Target establecido en: \(position)")
    }
    
    func clearTarget() {
        targetPosition = nil
        print("Target limpiado")
    }
    
    // MARK: - Voice Guidance
    
    private func provideVoiceGuidance(for person: KnownPerson,
                                    distance: Float,
                                    cameraTransform: simd_float4x4,
                                    facePosition: simd_float3?) {
        let now = Date()
        guard now.timeIntervalSince(lastInstructionTime) > 4.0 else { return }
        
        var instruction = ""
        let meters = Int(round(distance))
        
        if distance < 1.5 {
            instruction = "\(person.name) está justo frente a ti, a \(meters) metro\(meters == 1 ? "" : "s")"
        } else if let facePosition = facePosition {
            let cameraPos = simd_make_float3(cameraTransform.columns.3)
            let direction = facePosition - cameraPos
            let cameraForward = simd_make_float3(cameraTransform.columns.2) * -1
            
            let dotProduct = dot(normalize(direction), normalize(cameraForward))
            let crossProduct = cross(normalize(cameraForward), normalize(direction))
            
            if dotProduct > 0.8 {
                instruction = "\(person.name) está adelante, a \(meters) metros. Sigue recto"
            } else if crossProduct.y > 0.3 {
                instruction = "\(person.name) está a tu izquierda, a \(meters) metros. Gira a la izquierda"
            } else if crossProduct.y < -0.3 {
                instruction = "\(person.name) está a tu derecha, a \(meters) metros. Gira a la derecha"
            } else if dotProduct < -0.5 {
                instruction = "\(person.name) está detrás de ti, a \(meters) metros. Date la vuelta"
            } else {
                instruction = "\(person.name) está a \(meters) metros de distancia"
            }
        } else {
            instruction = "\(person.name) detectado a \(meters) metros"
        }
        
        if instruction != lastVoiceInstruction {
            speakInstruction(instruction)
            lastVoiceInstruction = instruction
            lastInstructionTime = now
        }
    }
    
    private func speakInstruction(_ text: String) {
        guard !text.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.1
        utterance.volume = 0.8
        
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
        
        print("Voz: \(text)")
    }
    
    // MARK: - Public Methods
    
    func removeAllArrows() {
        clearTarget()
        currentFaceTargets.removeAll()
        speechSynthesizer.stopSpeaking(at: .immediate)
        arrowEntity?.isEnabled = false
    }
    
    func stopUpdating() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func testVoiceInstructions() {
        speakInstruction("Sistema de navegación activado. Buscando personas cercanas.")
    }
    
    func stopVoiceGuidance() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        lastVoiceInstruction = ""
    }
    
    // Método para probar la flecha con una posición específica
    func addTestArrow(at position: SIMD3<Float> = [2, 0, -3]) {
        setTarget(position)
        print("Flecha de prueba añadida en: \(position)")
    }
    
    deinit {
        stopUpdating()
    }
}
