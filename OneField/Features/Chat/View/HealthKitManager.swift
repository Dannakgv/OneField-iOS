//
//  HealthKitManager.swift
//  OneField
//
//  Created by Danna Valencia on 04/10/25.
//

import HealthKit
import SwiftUI

@MainActor
@Observable
class HealthKitManager {
    private let healthStore = HKHealthStore()
    enum ReadRequestStatus {
        case notDetermined, requestCompleted, requestFailed
    }

    // HealthKit does not expose whether individual read permissions were granted.
    var authorizationStatus: ReadRequestStatus = .notDetermined
    var isAvailable = HKHealthStore.isHealthDataAvailable()
    var hasRequestedPermissions = false
    
    // Health data types we want to read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.workoutType()
    ]
    
    init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    func requestAuthorization() async -> Bool {
        guard isAvailable else { 
            print("HealthKit is not available on this device")
            return false 
        }
        
        print("Requesting HealthKit authorization for \(readTypes.count) data types")
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            hasRequestedPermissions = true
            await checkAuthorizationStatus()
            
            print("HealthKit authorization completed. Status: \(authorizationStatus)")
            return true
        } catch {
            authorizationStatus = .requestFailed
            print("HealthKit authorization error: \(error)")
            return false
        }
    }
    
    func canRequestPermissions() -> Bool {
        return isAvailable && authorizationStatus != .requestCompleted
    }
    
    func shouldShowSettingsAlert() -> Bool {
        return isAvailable && authorizationStatus == .requestCompleted
    }
    
    func openHealthSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func checkAuthorizationStatus() async {
        guard isAvailable else { return }
        do {
            let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: readTypes)
            hasRequestedPermissions = status == .unnecessary
            authorizationStatus = hasRequestedPermissions ? .requestCompleted : .notDetermined
        } catch {
            authorizationStatus = .requestFailed
        }
    }
    
    // MARK: - Heart Rate Data
    
    func getLatestHeartRate() async throws -> HKQuantitySample? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
                                                   end: Date(),
                                                   options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType,
                                    predicate: predicate,
                                    limit: 1,
                                    sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            
            healthStore.execute(query)
        }
    }
    
    func getHeartRateData(for period: TimePeriod) async throws -> [HKQuantitySample] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidDataType
        }
        
        let (startDate, endDate) = period.dateRange()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType,
                                    predicate: predicate,
                                    limit: HKObjectQueryNoLimit,
                                    sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            
            healthStore.execute(query)
        }
    }
    
    func getRestingHeartRate() async throws -> HKQuantitySample? {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.invalidDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
                                                   end: Date(),
                                                   options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: restingHRType,
                                    predicate: predicate,
                                    limit: 1,
                                    sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            
            healthStore.execute(query)
        }
    }
    
    func getHeartRateVariability() async throws -> HKQuantitySample? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            throw HealthKitError.invalidDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
                                                   end: Date(),
                                                   options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType,
                                    predicate: predicate,
                                    limit: 1,
                                    sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Step Count Data
    
    func getStepCount(for period: TimePeriod) async throws -> Double {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidDataType
        }
        
        let (startDate, endDate) = period.dateRange()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType,
                                        quantitySamplePredicate: predicate,
                                        options: .cumulativeSum) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: Self.stepQueryError(error))
                    return
                }
                
                guard let quantity = statistics?.sumQuantity() else {
                    continuation.resume(throwing: HealthKitError.noData)
                    return
                }
                let sum = quantity.doubleValue(for: HKUnit.count())
                continuation.resume(returning: sum)
            }
            
            healthStore.execute(query)
        }
    }
    
    nonisolated static func stepQueryError(_ error: Error) -> Error {
        // Statistics queries can report an empty store as HKError.errorNoData,
        // rather than returning statistics without a quantity.
        let healthError = error as NSError
        if healthError.domain == HKErrorDomain && healthError.code == HKError.Code.errorNoData.rawValue {
            return HealthKitError.noData
        }
        return error
    }

    // MARK: - Additional Health Data Methods
    
    func getLatestBodyMass() async throws -> HKQuantitySample? {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
                                                   end: Date(),
                                                   options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyMassType,
                                    predicate: predicate,
                                    limit: 1,
                                    sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            
            healthStore.execute(query)
        }
    }
    
    func getLatestSleepData() async throws -> HKCategorySample? {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.invalidDataType
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
                                                   end: Date(),
                                                   options: .strictEndDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType,
                                    predicate: predicate,
                                    limit: 1,
                                    sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples?.first as? HKCategorySample)
            }
            
            healthStore.execute(query)
        }
    }
    
    func generateHealthSummary() async throws -> String {
        var summary = "Here's your recent health data:\n\n"
        
        // Get today's steps vs recent average
        let todaySteps = try await getStepCount(for: .today)
        let weeklyAvgSteps = try await getStepCount(for: .thisWeek) / 7
        summary += "• Steps today: \(Int(todaySteps))"
        if weeklyAvgSteps > 0 {
            let comparison = todaySteps > weeklyAvgSteps ? "above" : "below"
            summary += " (\(comparison) your weekly average of \(Int(weeklyAvgSteps)))\n"
        } else {
            summary += "\n"
        }
        
        // Get latest heart rate with context
        if let heartRate = try await getLatestHeartRate() {
            let hrValue = Int(heartRate.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            let timeAgo = timeAgoString(from: heartRate.endDate)
            summary += "• Latest heart rate: \(hrValue) BPM (\(timeAgo))\n"
        } else {
            summary += "• Heart rate: No recent data available\n"
        }
        
        // Get resting heart rate with context
        if let restingHR = try await getRestingHeartRate() {
            let restingValue = Int(restingHR.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            let timeAgo = timeAgoString(from: restingHR.endDate)
            summary += "• Resting heart rate: \(restingValue) BPM (\(timeAgo))\n"
        } else {
            summary += "• Resting heart rate: No recent data available\n"
        }
        
        // Get heart rate variability (useful for stress assessment)
        if let hrv = try await getHeartRateVariability() {
            let hrvValue = hrv.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            let timeAgo = timeAgoString(from: hrv.endDate)
            summary += "• Heart rate variability: \(String(format: "%.1f", hrvValue)) ms (\(timeAgo))\n"
        } else {
            summary += "• Heart rate variability: No recent data available\n"
        }
        
        // Get latest sleep with quality assessment
        if let sleepData = try await getLatestSleepData() {
            let hours = sleepData.endDate.timeIntervalSince(sleepData.startDate) / 3600
            let quality = hours >= 7 ? "good" : hours >= 6 ? "fair" : "poor"
            let date = DateFormatter.localizedString(from: sleepData.startDate, dateStyle: .short, timeStyle: .none)
            summary += "• Latest sleep: \(String(format: "%.1f", hours)) hours on \(date) (\(quality))\n"
        } else {
            summary += "• Sleep: No recent data available\n"
        }
        
        // Get latest weight
        if let bodyMass = try await getLatestBodyMass() {
            let weightValue = bodyMass.quantity.doubleValue(for: HKUnit.pound())
            let timeAgo = timeAgoString(from: bodyMass.endDate)
            summary += "• Latest weight: \(String(format: "%.1f", weightValue)) lbs (\(timeAgo))\n"
        } else {
            summary += "• Weight: No recent data available\n"
        }
        
        return summary
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return minutes <= 1 ? "just now" : "\(minutes) minutes ago"
        } else if timeInterval < 86400 { // Less than 1 day
            let hours = Int(timeInterval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else { // 1 day or more
            let days = Int(timeInterval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
    
    // Generates a concise health summary for AI context
    func generateConciseHealthSummary() async throws -> String {
        var summary = "Recent health metrics: "
        var metrics: [String] = []
        
        // Steps
        let todaySteps = try await getStepCount(for: .today)
        metrics.append("Steps today: \(Int(todaySteps))")
        
        // Heart rate
        if let heartRate = try await getLatestHeartRate() {
            let hrValue = Int(heartRate.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            metrics.append("Latest HR: \(hrValue) BPM")
        }
        
        // Resting heart rate
        if let restingHR = try await getRestingHeartRate() {
            let restingValue = Int(restingHR.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
            metrics.append("Resting HR: \(restingValue) BPM")
        }
        
        // HRV for stress context
        if let hrv = try await getHeartRateVariability() {
            let hrvValue = hrv.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            metrics.append("HRV: \(String(format: "%.1f", hrvValue)) ms")
        }
        
        // Sleep
        if let sleepData = try await getLatestSleepData() {
            let hours = sleepData.endDate.timeIntervalSince(sleepData.startDate) / 3600
            metrics.append("Last sleep: \(String(format: "%.1f", hours))h")
        }
        
        summary += metrics.joined(separator: ", ")
        return summary
    }
    
    func queryStepCount(for prompt: String) async throws -> String {
        guard authorizationStatus == .requestCompleted else {
            throw HealthKitError.unauthorized
        }
        let period = extractTimePeriod(from: prompt.lowercased())
        let steps = try await getStepCount(for: period)
        return "You've taken \(Int(steps)) steps \(period.description)."
    }

    // MARK: - General Health Query
    
    func queryHealthData(for prompt: String) async throws -> String {
        // First check if we have proper authorization
        guard authorizationStatus == .requestCompleted else {
            throw HealthKitError.unauthorized
        }
        
        let lowercasePrompt = prompt.lowercased()
        
        // Check if this is likely a health-related query that should include health data
        let shouldIncludeHealthData = isHealthRelatedQuery(prompt: lowercasePrompt)
        
        // Heart rate queries
        if lowercasePrompt.contains("heart rate") {
            if lowercasePrompt.contains("resting") {
                if let restingHR = try await getRestingHeartRate() {
                    let value = restingHR.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    let date = DateFormatter.localizedString(from: restingHR.endDate, dateStyle: .short, timeStyle: .short)
                    return "Your most recent resting heart rate was \(Int(value)) BPM, recorded on \(date)."
                } else {
                    return "I couldn't find any recent resting heart rate data. Make sure you're wearing your Apple Watch regularly."
                }
            } else {
                if let heartRate = try await getLatestHeartRate() {
                    let value = heartRate.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    let date = DateFormatter.localizedString(from: heartRate.endDate, dateStyle: .short, timeStyle: .short)
                    return "Your most recent heart rate was \(Int(value)) BPM, recorded on \(date)."
                } else {
                    return "I couldn't find any recent heart rate data. Make sure you're wearing your Apple Watch."
                }
            }
        }
        
        // Step count queries
        else if lowercasePrompt.contains("step") || lowercasePrompt.contains("paso") {
            let period = extractTimePeriod(from: lowercasePrompt)
            let steps = try await getStepCount(for: period)
            return "You've taken \(Int(steps)) steps \(period.description)."
        }
        
        // Weight/Body Mass queries
        else if lowercasePrompt.contains("weight") || lowercasePrompt.contains("body mass") {
            if let bodyMass = try await getLatestBodyMass() {
                let value = bodyMass.quantity.doubleValue(for: HKUnit.pound())
                let date = DateFormatter.localizedString(from: bodyMass.endDate, dateStyle: .short, timeStyle: .none)
                return "Your most recent weight was \(String(format: "%.1f", value)) lbs, recorded on \(date)."
            } else {
                return "I couldn't find any recent weight data."
            }
        }
        
        // Sleep queries
        else if lowercasePrompt.contains("sleep") {
            if let sleepData = try await getLatestSleepData() {
                let hours = sleepData.endDate.timeIntervalSince(sleepData.startDate) / 3600
                let date = DateFormatter.localizedString(from: sleepData.startDate, dateStyle: .short, timeStyle: .none)
                return "Your most recent sleep session was \(String(format: "%.1f", hours)) hours on \(date)."
            } else {
                return "I couldn't find any recent sleep data."
            }
        }
        
        // General activity queries
        else if lowercasePrompt.contains("activity") || lowercasePrompt.contains("exercise") {
            let todaySteps = try await getStepCount(for: .today)
            if let heartRate = try await getLatestHeartRate() {
                let hrValue = Int(heartRate.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                return "Today you've taken \(Int(todaySteps)) steps and your most recent heart rate was \(hrValue) BPM."
            } else {
                return "Today you've taken \(Int(todaySteps)) steps. I couldn't find recent heart rate data."
            }
        }
        
        // Health summary for comprehensive queries
        else if lowercasePrompt.contains("health summary") || lowercasePrompt.contains("health overview") {
            return try await generateHealthSummary()
        }
        
        // Stress/anxiety related queries - provide HRV and heart rate data
        else if lowercasePrompt.contains("stress") || lowercasePrompt.contains("anxious") || lowercasePrompt.contains("nervous") {
            var stressResponse = "Here's your recent stress-related health data:\n\n"
            
            if let hrv = try await getHeartRateVariability() {
                let hrvValue = hrv.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                let timeAgo = timeAgoString(from: hrv.endDate)
                stressResponse += "• Heart Rate Variability: \(String(format: "%.1f", hrvValue)) ms (\(timeAgo))\n"
                stressResponse += "  Higher HRV typically indicates better stress resilience.\n"
            }
            
            if let restingHR = try await getRestingHeartRate() {
                let restingValue = Int(restingHR.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                let timeAgo = timeAgoString(from: restingHR.endDate)
                stressResponse += "• Resting Heart Rate: \(restingValue) BPM (\(timeAgo))\n"
            }
            
            if let heartRate = try await getLatestHeartRate() {
                let hrValue = Int(heartRate.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                let timeAgo = timeAgoString(from: heartRate.endDate)
                stressResponse += "• Latest Heart Rate: \(hrValue) BPM (\(timeAgo))\n"
            }
            
            return stressResponse
        }
        
        // If this seems like a health-related query but didn't match specific patterns,
        // provide a comprehensive health summary to give context to the AI
        else if shouldIncludeHealthData {
            let summary = try await generateHealthSummary()
            return "Based on your health data:\n\n\(summary)\n\nNote: This is your recent health data that might be relevant to your question. Feel free to ask me about any patterns or concerns you notice."
        }
        
        // If no health relation is detected, return empty string to let the AI handle it normally
        return ""
    }
    
    private func isHealthRelatedQuery(prompt: String) -> Bool {
        // Emotional/physical state keywords that might benefit from health context
        let emotionalStateKeywords = [
            "feeling", "feel", "sick", "tired", "exhausted", "anxious", "stressed", "worried",
            "scared", "nervous", "dizzy", "weak", "strong", "energy", "fatigue", "mood",
            "depression", "sad", "happy", "excited", "calm", "restless", "jittery"
        ]
        
        // Physical symptom keywords
        let physicalSymptomKeywords = [
            "chest pain", "shortness of breath", "breathing", "palpitations", "headache",
            "nausea", "pain", "ache", "sore", "hurt", "uncomfortable", "swelling",
            "fever", "chills", "sweating", "trembling", "shaking"
        ]
        
        // Health inquiry keywords
        let healthInquiryKeywords = [
            "health", "medical", "symptoms", "condition", "wellness", "vitals", "monitoring",
            "checkup", "assessment", "analysis", "trend", "pattern", "normal", "abnormal",
            "concern", "worried about", "should i", "is this normal", "what does this mean"
        ]
        
        // Time-based health queries
        let temporalHealthKeywords = [
            "lately", "recently", "past few days", "this week", "today", "yesterday",
            "getting worse", "getting better", "improving", "declining"
        ]
        
        let allKeywords = emotionalStateKeywords + physicalSymptomKeywords + healthInquiryKeywords + temporalHealthKeywords
        
        return allKeywords.contains { prompt.contains($0) }
    }
    
    private func extractTimePeriod(from prompt: String) -> TimePeriod {
        if prompt.contains("yesterday") || prompt.contains("ayer") {
            return .yesterday
        } else if prompt.contains("last 7") || prompt.contains("últimos 7") {
            return .last7Days
        } else if prompt.contains("last 30") || prompt.contains("últimos 30") {
            return .last30Days
        } else if prompt.contains("today") || prompt.contains("hoy") {
            return .today
        } else if prompt.contains("week") || prompt.contains("semana") {
            return .thisWeek
        } else if prompt.contains("month") || prompt.contains("mes") {
            return .thisMonth
        } else {
            return .today
        }
    }
}

// MARK: - Supporting Types

enum HealthKitError: LocalizedError {
    case invalidDataType
    case noData
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidDataType:
            return "Invalid health data type"
        case .noData:
            return "No health data available"
        case .unauthorized:
            return "HealthKit access not authorized"
        }
    }
}

enum TimePeriod {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case last7Days
    case last30Days
    
    func dateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .yesterday:
            let end = calendar.startOfDay(for: now)
            return (calendar.date(byAdding: .day, value: -1, to: end) ?? end, end)
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return (startOfDay, now)
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (sevenDaysAgo, now)
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (thirtyDaysAgo, now)
        }
    }
    
    var description: String {
        switch self {
        case .yesterday:
            return "yesterday"
        case .today:
            return "today"
        case .thisWeek:
            return "this week"
        case .thisMonth:
            return "this month"
        case .last7Days:
            return "in the last 7 days"
        case .last30Days:
            return "in the last 30 days"
        }
    }
}
