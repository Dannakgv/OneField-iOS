import SwiftUI
import RealityKit

struct MainARView: View {
    @StateObject private var viewModel = ARGuidanceViewModel()
    @StateObject private var faceRecognitionManager = FaceRecognitionManager()
    @State private var showingRegistration = false
    @State private var showingPeopleList = false
    
    var body: some View {
        ZStack {
            // AR View
            FindMyARViewContainer(viewModel: viewModel, faceRecognitionManager: faceRecognitionManager)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
            
                Spacer()
                
                // Recognized Faces
                if !faceRecognitionManager.recognizedFaces.isEmpty {
                    recognizedFacesSection
                        .padding(.horizontal, 20)
                }
                
                // Controls
                controlPanel
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingRegistration) {
            FaceRegistrationView(faceRecognitionManager: faceRecognitionManager)
        }
        .sheet(isPresented: $showingPeopleList) {
            PeopleListView(faceRecognitionManager: faceRecognitionManager)
        }
    }
    
    private var headerView: some View {
        HStack {
            ControlButton(
                icon: "person.2.fill",
                label: "People",
                color: .deepBlue
            ) {
                showingPeopleList.toggle()
            }
            
            Spacer()
            
            ControlButton(
                icon: "person.crop.circle.badge.plus",
                label: "Register",
                color: .deepBlue
            ) {
                showingRegistration.toggle()
            }
        }
    }
    
    private var recognizedFacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognized")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(faceRecognitionManager.recognizedFaces.values), id: \.id) { person in
                        RecognizedPersonCard(person: person)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.darkOverlay)
        )
    }
    
    private var controlPanel: some View {
        HStack(spacing: 15) {
            WideControlButton(
                icon: viewModel.voiceInstructionsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                label: "Voice",
                color: viewModel.voiceInstructionsEnabled ? .limeGreen : .gray
            ) {
                viewModel.toggleVoiceInstructions()
            }
            
            WideControlButton(
                icon: viewModel.isTracking ? "pause.fill" : "play.fill",
                label: viewModel.isTracking ? "Pause" : "Start",
                color: viewModel.isTracking ? .teal : .deepBlue
            ) {
                viewModel.toggleTracking()
            }
        }
    }
}

struct WideControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
            )
        }
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
        }
    }
}

struct RecognizedPersonCard: View {
    let person: KnownPerson
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.skyBlue)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Circle()
                        .fill(Color.limeGreen)
                        .frame(width: 6, height: 6)
                    
                    Text("Detected")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }
}

#Preview {
    MainARView()
}
