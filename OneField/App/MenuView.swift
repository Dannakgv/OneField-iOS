//
//  menu.swift
//  OneField
//
//  Created by Danna Valencia on 11/10/25.
//

import SwiftUI

enum AppFunction: String, CaseIterable, Identifiable {
    case assistent = "Chat with your AI assistent"
    case arGuide = "Find your way in AR"
    case findFriends = "Meet up with friends"
    case translator = "Instant translations"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .assistent: return "bubble.fill"
        case .arGuide: return "location.fill"
        case .findFriends: return "binoculars.fill"
        case .translator: return "waveform.badge.magnifyingglass"
        }
    }

    var color: Color {
        switch self {
        case .assistent: return .brightPurple
        case .arGuide: return .teal
        case .findFriends: return .limeGreen
        case .translator: return .deepBlue
        }
    }
}

// seleccionar el modo
struct MenuView: View {
    @State private var mode: AppFunction? = nil

    var body: some View {
        NavigationStack {
            ZStack {

                LinearGradient(
                    gradient: Gradient(colors: [.softLavender.opacity(0.9), .lightBackground]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        
                        // Head
                        VStack(spacing: 8) {
                            Text("One Field")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundColor(.darkText)
                                .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 2)

                            Text("From every corner to one field")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.darkText.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 60)
                        
                        PhotoCarouselView(images: ["match","winners","qualifiers","groups"])
                            .padding(.horizontal, 10)
                        // Functions
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20)
                            ],
                            spacing: 26
                        ) {
                            ForEach(AppFunction.allCases) { m in
                                Button {
                                    mode = m
                                } label: {
                                    VStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(m.color.opacity(0.15))
                                                .frame(width: 70, height: 70)
                                                .overlay(
                                                    Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
                                                )

                                            Image(systemName: m.icon)
                                                .font(.system(size: 30, weight: .semibold))
                                                .foregroundColor(m.color)
                                        }

                                        Text(m.rawValue)
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundColor(.darkText)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text(subtitle(for: m))
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundColor(.darkText.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.horizontal, 4)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 28)
                                            .fill(Color.white)
                                            .shadow(color: m.color.opacity(0.25), radius: 8, x: 0, y: 4)
                                            .shadow(color: .white.opacity(0.9), radius: 5, x: 0, y: -2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)


                    }
                }
            }

            .navigationDestination(item: $mode) { m in
                switch m {
                case .assistent:
                    ChatView()
                case .arGuide:
                    CSC26View()
                case .findFriends:
                    MainARView()
                case .translator:
                    ModeSelectorView()
                }
            }
        }
    }

    private func subtitle(for mode: AppFunction) -> String {
        switch mode {
        case .assistent: return "Your personal guide for everything World Cup."
        case .arGuide: return "Let arrows guide you to restrooms, exits, and more."
        case .findFriends: return "See where your people are in real time."
        case .translator: return "Break language barriers in seconds."
        }
    }
}


#Preview {
    MenuView()
}
