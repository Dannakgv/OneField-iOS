//
//  DetectedFace.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//

import Foundation
import Vision
import ARKit

struct DetectedFace: Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    var worldPosition: simd_float3?
    var distance: Float?
    let confidence: Float
    let timestamp: Date
    
    init(boundingBox: CGRect, worldPosition: simd_float3?, distance: Float?, confidence: Float, timestamp: Date) {
        self.boundingBox = boundingBox
        self.worldPosition = worldPosition
        self.distance = distance
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

struct ArrowGuide {
    let position: simd_float3
    let direction: simd_float3
    let targetFaceId: UUID
    var node: SCNNode?
}
