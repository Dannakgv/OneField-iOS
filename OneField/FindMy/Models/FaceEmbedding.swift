//
//  FaceEmbedding.swift
//  OneField
//
//  Created by Victoria Marin on 06/10/25.
//
import Foundation

struct FaceEmbedding {
    let descriptor: [Float]
    let personId: UUID
    
    func similarity(to other: FaceEmbedding) -> Float {
        guard descriptor.count == other.descriptor.count else { return 0 }
        
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        
        for i in 0..<descriptor.count {
            dotProduct += descriptor[i] * other.descriptor[i]
            normA += descriptor[i] * descriptor[i]
            normB += other.descriptor[i] * other.descriptor[i]
        }
        
        let magnitude = sqrt(normA) * sqrt(normB)
        return magnitude > 0 ? dotProduct / magnitude : 0
    }
    
    func distance(to other: FaceEmbedding) -> Float {
        guard descriptor.count == other.descriptor.count else { return Float.greatestFiniteMagnitude }
        
        var sum: Float = 0
        for i in 0..<descriptor.count {
            let diff = descriptor[i] - other.descriptor[i]
            sum += diff * diff
        }
        
        return sqrt(sum)
    }
}
