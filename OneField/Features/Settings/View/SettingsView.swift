//
//  SettingsView.swift
//  OneField
//
//  Created by Santiago Quihui on 04/10/25.
//

import SwiftUI
import HealthKit

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section("AI Model") {
                    HStack {
                        Circle()
                            .fill(viewModel.modelStatusColor)
                            .frame(width: 8, height: 8)
                        Text("Status")
                        Spacer()
                        Text(viewModel.modelStatusText)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Health Data") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Circle()
                            .fill(viewModel.healthStatusColor)
                            .frame(width: 8, height: 8)
                        Text("Health Access")
                        Spacer()
                        Text(viewModel.healthStatusText)
                            .foregroundColor(.secondary)
                    }
                    
                    if viewModel.canRequestHealthPermissions {
                        Button("Enable Health Data Access") {
                            Task {
                                await viewModel.requestHealthAuthorization()
                            }
                        }
                    } else if viewModel.shouldShowHealthSettings {
                        Button("Open Health Settings") {
                            viewModel.openHealthSettings()
                        }
                    }
                    
                    Text(viewModel.healthDescriptionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Health Data Access", isPresented: $viewModel.showingHealthAlert) {
                Button("Open Settings") {
                    // The view model handles opening settings
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To access your health data, please enable permissions in the Health app settings. Go to Settings > Privacy & Security > Health > OneField and enable the data types you want to share.")
            }
        }
    }
}
