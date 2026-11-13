//
//  HealthDataPreviewView.swift
//  OneField
//
//  Created by Danna Valencia on 04/10/25.
//

import SwiftUI
import HealthKit

struct HealthDataPreviewView: View {
    @State private var healthKitManager = HealthKitManager()
    @State private var heartRate: String = "Loading..."
    @State private var restingHeartRate: String = "Loading..."
    @State private var todaySteps: String = "Loading..."
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Authorization Status") {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        
                        Text(statusText)
                        
                        Spacer()
                        
                        if healthKitManager.authorizationStatus == .notDetermined {
                            Button("Request Access") {
                                Task {
                                    await healthKitManager.requestAuthorization()
                                    await loadHealthData()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                
                if healthKitManager.authorizationStatus == .requestCompleted {
                    Section("Recent Health Data") {
                        healthDataRow(title: "Heart Rate", value: heartRate, icon: "heart.fill")
                        healthDataRow(title: "Resting Heart Rate", value: restingHeartRate, icon: "heart")
                        healthDataRow(title: "Steps Today", value: todaySteps, icon: "figure.walk")
                    }
                    
                    Section("Sample Queries") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Try asking these questions in the chat:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(sampleQueries, id: \.self) { query in
                                Text("• \(query)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Health Data Access Required")
                                .font(.headline)
                            
                            Text("To get personalized health insights in the chat, please grant access to your health data. This enables the AI to answer questions about your heart rate, activity levels, and other health metrics.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Health Data")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadHealthData()
            }
        }
        .onAppear {
            Task {
                await loadHealthData()
            }
        }
    }
    
    @ViewBuilder
    private func healthDataRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch healthKitManager.authorizationStatus {
        case .requestCompleted:
            return .green
        case .requestFailed:
            return .red
        case .notDetermined:
            return .yellow
        }
    }
    
    private var statusText: String {
        if !healthKitManager.isAvailable {
            return "HealthKit not available"
        }
        
        switch healthKitManager.authorizationStatus {
        case .requestCompleted:
            return "Permission request completed"
        case .requestFailed:
            return "Permission request failed"
        case .notDetermined:
            return "Access not requested"
        }
    }
    
    private var sampleQueries: [String] {
        [
            "What's my current heart rate?",
            "How many steps have I taken today?",
            "What's my resting heart rate?",
            "Show me my activity level this week",
            "How many steps did I take yesterday?",
            "What was my heart rate during my last workout?"
        ]
    }
    
    @MainActor
    private func loadHealthData() async {
        guard healthKitManager.authorizationStatus == .requestCompleted else {
            heartRate = "Access required"
            restingHeartRate = "Access required"
            todaySteps = "Access required"
            return
        }
        
        isLoading = true
        
        async let heartRateTask = loadHeartRate()
        async let restingHeartRateTask = loadRestingHeartRate()
        async let stepsTask = loadTodaySteps()
        
        await heartRateTask
        await restingHeartRateTask
        await stepsTask
        
        isLoading = false
    }
    
    private func loadHeartRate() async {
        do {
            if let sample = try await healthKitManager.getLatestHeartRate() {
                let value = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                await MainActor.run {
                    heartRate = "\(value) BPM"
                }
            } else {
                await MainActor.run {
                    heartRate = "No data"
                }
            }
        } catch {
            await MainActor.run {
                heartRate = "Error loading"
            }
        }
    }
    
    private func loadRestingHeartRate() async {
        do {
            if let sample = try await healthKitManager.getRestingHeartRate() {
                let value = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                await MainActor.run {
                    restingHeartRate = "\(value) BPM"
                }
            } else {
                await MainActor.run {
                    restingHeartRate = "No data"
                }
            }
        } catch {
            await MainActor.run {
                restingHeartRate = "Error loading"
            }
        }
    }
    
    private func loadTodaySteps() async {
        do {
            let steps = try await healthKitManager.getStepCount(for: .today)
            await MainActor.run {
                todaySteps = "\(Int(steps))"
            }
        } catch {
            await MainActor.run {
                todaySteps = "Error loading"
            }
        }
    }
}

#Preview {
    HealthDataPreviewView()
}
