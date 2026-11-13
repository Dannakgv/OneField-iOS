import SwiftUI
import AVFoundation

struct FaceRegistrationView: View {
    @StateObject private var viewModel: FaceRegistrationViewModel
    @State private var personName = ""
    @State private var showingSuccess = false
    @Environment(\.dismiss) var dismiss
    
    init(faceRecognitionManager: FaceRecognitionManager) {
        _viewModel = StateObject(wrappedValue: FaceRegistrationViewModel(
            faceRecognitionManager: faceRecognitionManager
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        headerSection
                        
                        // Camera Preview
                        cameraPreviewSection
                        
                        // Progress Indicators
                        if viewModel.isCapturing {
                            progressIndicatorsSection
                        }
                        
                        // Controls
                        controlsSection
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Register Face")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("Success!", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(personName) has been registered successfully")
            }
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            Circle()
                .fill(Color.skyBlue.opacity(0.08))
                .frame(width: 200)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.limeGreen.opacity(0.06))
                .frame(width: 150)
                .offset(x: 150, y: 300)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.deepBlue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "faceid")
                    .font(.system(size: 40))
                    .foregroundColor(.deepBlue)
            }
            
            Text("Register New Person")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.darkText)
            
            Text(viewModel.message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Camera Preview Section
    private var cameraPreviewSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.lightCard)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                CameraPreviewView(session: viewModel.captureSession)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(4)
                
                // Face detection indicator
                if viewModel.detectedFaceCount > 0 {
                    VStack {
                        HStack {
                            Spacer()
                            faceDetectionBadge
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(height: 300)
            .padding(.horizontal, 24)
            
            // Capture Button
            if viewModel.isCapturing {
                captureButton
            }
        }
    }
    
    private var faceDetectionBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "face.smiling.fill")
                .foregroundColor(.white)
            
            Text("\(viewModel.detectedFaceCount) Face")
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(viewModel.detectedFaceCount == 1 ? Color.limeGreen : Color.teal)
        )
    }
    
    private var captureButton: some View {
        Button(action: viewModel.capturePhoto) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(viewModel.detectedFaceCount == 1 ? Color.deepBlue : Color.gray)
                        .frame(width: 70, height: 70)
                        .shadow(color: viewModel.detectedFaceCount == 1 ? .deepBlue.opacity(0.3) : .clear, radius: 10)
                    
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(viewModel.detectedFaceCount == 1 ? "Tap to Capture" : "Position Face")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.detectedFaceCount == 1 ? .deepBlue : .gray)
            }
        }
        .disabled(viewModel.detectedFaceCount != 1)
    }
    
    // MARK: - Progress Indicators
    private var progressIndicatorsSection: some View {
        VStack(spacing: 16) {
            Text("Capture Progress")
                .font(.headline)
                .foregroundColor(.darkText)
            
            HStack(spacing: 12) {
                ForEach(0..<5) { index in
                    ProgressIndicator(
                        isFilled: index < viewModel.capturedFaces.count,
                        number: index + 1
                    )
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 20) {
            if !viewModel.isCapturing && viewModel.capturedFaces.isEmpty {
                startCaptureButton
            } else if !viewModel.capturedFaces.isEmpty {
                nameInputSection
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var startCaptureButton: some View {
        Button {
            viewModel.startCapture()
        } label: {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Face Capture")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Capture 5 photos from different angles")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.deepBlue)
            )
        }
    }
    
    private var nameInputSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.limeGreen)
                
//                Text("Photos Captured!")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                    .foregroundColor(.darkText)
                
                Text("Enter the person's name to complete registration")
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Person's Name")
                    .font(.headline)
                    .foregroundColor(.darkText)
                
                TextField("Enter name...", text: $personName)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lightCard)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    )
            }
            
            actionButtons
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                viewModel.capturedFaces.removeAll()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Button("Save Person") {
                if viewModel.registerPerson(name: personName) {
                    showingSuccess = true
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(personName.isEmpty)
        }
    }
}

struct ProgressIndicator: View {
    let isFilled: Bool
    let number: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isFilled ? Color.limeGreen : Color.lightCard)
                .frame(width: 44, height: 44)
                .shadow(color: isFilled ? .limeGreen.opacity(0.3) : .clear, radius: 5)
            
            if isFilled {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundColor(.white)
            } else {
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
        .scaleEffect(isFilled ? 1.1 : 1.0)
        .animation(.spring(), value: isFilled)
    }
}

#Preview {
    FaceRegistrationView(faceRecognitionManager: FaceRecognitionManager())
}
