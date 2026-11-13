//
//  ModeSelectorView.swift
//  OneField
//
//  Created by Angela Pesina on 08/10/25.

import SwiftUI

extension UIColor {
    static let softLavender = UIColor(red: 185/255, green: 181/255, blue: 255/255, alpha: 1)
    static let deepBlue = UIColor(red: 79/255, green: 79/255, blue: 186/255, alpha: 1)
    static let teal = UIColor(red: 60/255, green: 136/255, blue: 126/255, alpha: 1)
    static let limeGreen = UIColor(red: 159/255, green: 211/255, blue: 86/255, alpha: 1)
    static let brightPurple = UIColor(red: 126/255, green: 116/255, blue: 241/255, alpha: 1)
    static let lightPurple = UIColor(red: 229/255, green: 228/255, blue: 250/255, alpha: 1)
    static let lightBackground = UIColor(red: 248/255, green: 248/255, blue: 252/255, alpha: 1)
    static let darkText = UIColor(red: 29/255, green: 29/255, blue: 31/255, alpha: 1)
    static let warmOrange = UIColor(red: 255/255, green: 166/255, blue: 82/255, alpha: 1)
}

// Enum con los modos de la app
enum AppMode: String, CaseIterable, Identifiable {
    case conversation = "Traducción en tiempo real"
    case voiceToText = "Voz a texto (Subtítulos)"
    case textToSpeech = "Texto a voz (Audio)"
    case lsmTranslator = "Traductor de señas"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .conversation: return "person.2.wave.2.fill"
        case .voiceToText: return "waveform.and.mic"
        case .textToSpeech: return "speaker.wave.3.fill"
        case .lsmTranslator: return "hand.raised.fill"
        }
    }

    var color: Color {
        switch self {
        case .conversation: return .brightPurple
        case .voiceToText: return .teal
        case .textToSpeech: return .limeGreen
        case .lsmTranslator: return .deepBlue
        }
    }
}

// seleccionar el modo
struct ModeSelectorView: View {
    @State private var mode: AppMode? = nil

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

                        VStack(spacing: 8) {
                            Text("Comunicación")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundColor(.darkText)
                                .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 2)

                            Text("Selecciona el modo de accesibilidad que deseas utilizar")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.darkText.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 60)

                        VStack(spacing: 26) {
                            ForEach(AppMode.allCases) { m in
                                Button {
                                    mode = m
                                } label: {
                                    HStack(spacing: 20) {
                                        ZStack {
                                            Circle()
                                                .fill(m.color.opacity(0.2))
                                                .frame(width: 70, height: 70)
                                                .overlay(
                                                    Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
                                                )

                                            Image(systemName: m.icon)
                                                .font(.system(size: 30, weight: .semibold))
                                                .foregroundColor(m.color)
                                        }

                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(m.rawValue)
                                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                                                .foregroundColor(.darkText)
                                                .multilineTextAlignment(.leading)

                                            Text(subtitle(for: m))
                                                .font(.system(size: 15, design: .rounded))
                                                .foregroundColor(.darkText.opacity(0.7))
                                                .multilineTextAlignment(.leading)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.darkText.opacity(0.3))
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
                                .padding(.horizontal, 30)
                            }
                        }
                        .padding(.top, 10)

                        VStack {
                            HStack(alignment: .top, spacing: 15) {
                                ZStack {
                                    Circle()
                                        .fill(Color.warmOrange.opacity(0.15))
                                        .frame(width: 55, height: 55)

                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.warmOrange)
                                        .font(.system(size: 26, weight: .semibold))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Consejo del día")
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundColor(.warmOrange)

                                    Text("🎧 Usa audífonos para evitar eco si hablas y escuchas al mismo tiempo. Esto mejora la claridad y reduce distracciones.")
                                        .font(.system(size: 16, design: .rounded))
                                        .foregroundColor(.darkText.opacity(0.8))
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(20)
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white)
                                .shadow(color: .warmOrange.opacity(0.25), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal, 30)
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationDestination(item: $mode) { m in
                switch m {
                case .conversation:
                    ConversationView()
                case .voiceToText:
                    DeafView()
                case .textToSpeech:
                    BlindView()
                case .lsmTranslator:
                    LSMCameraView()
                }
            }
        }
    }

    private func subtitle(for mode: AppMode) -> String {
        switch mode {
        case .conversation: return "Habla y escucha traducciones en tiempo real"
        case .voiceToText: return "Convierte tu voz en subtítulos accesibles"
        case .textToSpeech: return "Comprende lo que se habla en tu entorno"
        case .lsmTranslator: return "Traduce señas desde la cámara en vivo"
        }
    }
}


#Preview {
    ModeSelectorView()
}
