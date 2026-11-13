//
//  DeafView.swift
//  OneField
//
//  Created by Angela Pesina on 08/10/25.
//

import SwiftUI

 // voz a texto

struct DeafView: View {
    // reconocimiento de voz
    @StateObject private var stt = STTManager(localeId: "es-MX")
    
    // modelos de traducción CoreML
    private let traductorESaEN = MLTraductorService()!
    private let traductorENaES = MLTraductorInversoService()!
    
    @State private var translated: String = ""
    
    // traducción
    @State private var mostrarTraduccion: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Subtítulos en vivo")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.darkText)
                    
                    Text("Reconoce lo que se dice a tu alrededor y tradúcelo al instante")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.darkText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 20)
                
                // texto en vivo (subtitulos)
                ScrollView {
                    Text(stt.transcript.isEmpty ? "Empieza a hablar..." : stt.transcript)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundColor(.darkText)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: .gray.opacity(0.2), radius: 6, x: 0, y: 3)
                        )
                        .padding(.horizontal, 20)
                }
                .frame(maxHeight: 300)
                
                // traducción generada (si está activada)
                if mostrarTraduccion {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Traducción generada", systemImage: "text.bubble.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.purple)
                            .padding(.leading, 20)
                        
                        Text(translated.isEmpty ? "— Traducción aparecerá aquí —" : translated)
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundColor(.darkText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .shadow(color: .purple.opacity(0.2), radius: 5, x: 0, y: 3)
                            )
                            .padding(.horizontal, 20)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                //  controles principales
                HStack(spacing: 16) {
                    // iniciar el reconocimiento
                    Button {
                        try? stt.start()
                    } label: {
                        Label("Escuchar", systemImage: "ear.badge.waveform")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    
                    // detener el reconocimiento
                    Button {
                        stt.stop()
                    } label: {
                        Label("Parar", systemImage: "stop.circle.fill")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    
                    // traducir el texto
                    Button {
                        let frase = stt.transcript.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let idioma = LanguageDetector.detectCode(for: frase)?.code ?? "es"

                        // Traducción automática en ambos sentidos (on-device)
                        if idioma == "es" {
                            translated = traductorESaEN.traducir(texto: frase)
                        } else if idioma == "en" {
                            translated = traductorENaES.traducir(texto: frase)
                        } else {
                            translated = "[Idioma no soportado]"
                        }

                        // Muestra el texto traducido
                        withAnimation {
                            mostrarTraduccion = true
                        }
                    } label: {
                        Label("Traducir", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
                .padding(.bottom, 30)
            }
        }
        // permisos
        .task {
            try? await stt.authorize()
        }
    }
}
