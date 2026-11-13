import SwiftUI

struct PeopleListView: View {
    @ObservedObject var faceRecognitionManager: FaceRecognitionManager
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteAlert = false
    @State private var personToDelete: KnownPerson?

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                GeometryReader { geometry in
                    // Formas decorativas de fondo
                    Circle()
                        .fill(Color.skyBlue.opacity(0.08))
                        .frame(width: 200)
                        .offset(x: -50, y: -100)
                    
                    Circle()
                        .fill(Color.limeGreen.opacity(0.06))
                        .frame(width: 150)
                        .offset(x: geometry.size.width - 80, y: geometry.size.height - 200)
                }
                .ignoresSafeArea()
                
                if faceRecognitionManager.getKnownPeople().isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(faceRecognitionManager.getKnownPeople()) { person in
                                ModernPersonCard(person: person)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            personToDelete = person
                                            showingDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Registered People")
            .navigationBarTitleDisplayMode(.large)
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
            .alert("Delete Person", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let person = personToDelete {
                        faceRecognitionManager.removePerson(person)
                    }
                }
            } message: {
                Text("Are you sure you want to delete \(personToDelete?.name ?? "this person")?")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.deepBlue.opacity(0.3))
            
            Text("No People Registered")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.darkText)
            
            Text("Tap the register button to add someone")
                .font(.body)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 100)
    }
}

struct ModernPersonCard: View {
    let person: KnownPerson

    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(Color.deepBlue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                if let photoData = person.photos.first,
                   let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundColor(.deepBlue)
                }
            }

            // Person Info
            VStack(alignment: .leading, spacing: 6) {
                Text(person.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.darkText)

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.deepBlue)
                        
                        Text("\(person.timesDetected) detections")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    if let lastSeen = person.lastSeen {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.teal)
                            
                            Text(formatDate(lastSeen))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lightCard)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    PeopleListView(faceRecognitionManager: FaceRecognitionManager())
}
