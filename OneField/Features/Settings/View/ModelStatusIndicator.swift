//
//  ModelStatusIndicator.swift
//  OneField
//
//  Created by Santiago Quihui on 04/10/25.
//

import SwiftUI
import FoundationModels

struct ModelStatusIndicator: View {
    private let model = SystemLanguageModel.default
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch model.availability {
        case .available:
            return .green
        case .unavailable:
            return .red
        }
    }
    
    private var statusText: String {
        switch model.availability {
        case .available:
            return "Available"
        case .unavailable(.deviceNotEligible):
            return "Device Not Eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Not Enabled"
        case .unavailable(.modelNotReady):
            return "Not Ready"
        case .unavailable(let other):
            return "Unavailable"
        }
    }
}
