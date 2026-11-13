//
//  SettingsViewModel.swift
//  OneField
//
//  Created by Santiago Quihui on 06/10/25.
//

import SwiftUI
import FoundationModels
import HealthKit

@MainActor
@Observable
class SettingsViewModel {
    // MARK: - State Properties
    var showingHealthAlert = false
    
    // MARK: - Dependencies
    private let healthKitManager: HealthKitManager
    private let model = SystemLanguageModel.default
    
    // MARK: - Initialization
    init(healthKitManager: HealthKitManager? = nil) {
        self.healthKitManager = healthKitManager ?? HealthKitManager()
    }
    
    // MARK: - Public Methods
    func requestHealthAuthorization() async {
        await healthKitManager.requestAuthorization()
    }
    
    func openHealthSettings() {
        showingHealthAlert = true
        healthKitManager.openHealthSettings()
    }
    
    // MARK: - Computed Properties
    var modelStatusColor: Color {
        switch model.availability {
        case .available:
            return .green
        case .unavailable:
            return .red
        }
    }
    
    var modelStatusText: String {
        switch model.availability {
        case .available:
            return "Available"
        case .unavailable(.deviceNotEligible):
            return "Device not eligible"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Not enabled"
        case .unavailable(.modelNotReady):
            return "Downloading"
        case .unavailable:
            return "Unavailable"
        }
    }
    
    var healthStatusText: String {
        if !healthKitManager.isAvailable {
            return "Not Available"
        }
        
        switch healthKitManager.authorizationStatus {
        case .requestCompleted:
            return "Request completed"
        case .requestFailed:
            return "Request failed"
        case .notDetermined:
            return "Not Set"
        }
    }
    
    var healthStatusColor: Color {
        if !healthKitManager.isAvailable {
            return .orange
        }
        
        switch healthKitManager.authorizationStatus {
        case .requestCompleted:
            return .green
        case .requestFailed:
            return .red
        case .notDetermined:
            return .yellow
        }
    }
    
    var canRequestHealthPermissions: Bool {
        healthKitManager.canRequestPermissions()
    }
    
    var shouldShowHealthSettings: Bool {
        healthKitManager.shouldShowSettingsAlert()
    }
    
    var isHealthKitAvailable: Bool {
        healthKitManager.isAvailable
    }
    
    var healthDescriptionText: String {
        if healthKitManager.isAvailable {
            return "Access to health data allows the AI to provide personalized insights about your heart rate, steps, activity, and more."
        } else {
            return "Health data is not available on this device."
        }
    }
}
