//
//  ConversationView.swift
//  OneField
//
//  Created by Angela Pesina on 08/10/25.
//

import SwiftUI

// conversaciones entre 2 idiomas distintos
struct ConversationView: View {
    // instancias del reconocimiento de voz (Speech to Text)
    @StateObject private var sttA = STTManager(localeId: "es-MX")
    @StateObject private var sttB = STTManager(localeId: "en-US")
    
    // modelos CoreML que traducen entre idiomas
    private let traductorESaEN = MLTraductorService()!
    private let traductorENaES = MLTraductorInversoService()!
    
    // servicio de texto a voz
    private let tts = TTSService()

    // guardan las traducciones generadas
    @State private var translatedA: String = ""
    @State private var translatedB: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {

                Text("Conversación en tiempo real")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)

                // persona a
                conversationSection(
                    title: "Español",
                    color: .mint,
                    stt: sttA,
                    original: sttA.transcript,
                    translated: translatedA,
                    langCode: "en-US", // se traducirá al inglés
                    onTranslate: {
                        // Limpia la frase y la manda al modelo de traducción
                        let frase = sttA.transcript.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        translatedA = traductorESaEN.traducir(texto: frase)
                    }
                )

                // persona b
                conversationSection(
                    title: "Inglés",
                    color: .teal,
                    stt: sttB,
                    original: sttB.transcript,
                    translated: translatedB,
                    langCode: "es-MX", // se traducirá al español
                    onTranslate: {
                        let frase = sttB.transcript.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        translatedB = traductorENaES.traducir(texto: frase)
                    }
                )
            }
            .padding()
        }
        // permisos
        .task {
            try? await sttA.authorize()
            try? await sttB.authorize()
        }
    }

 // crear el "componente" de conversación
    func conversationSection(
        title: String,
        color: Color,
        stt: STTManager,
        original: String,
        translated: String,
        langCode: String,
        onTranslate: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
        
            Label(title, systemImage: "person.crop.circle.fill")
                .font(.headline)
                .foregroundColor(color)

    
            if !original.isEmpty {
                Text("🗣️ Transcripción")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(original)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }

           
            if !translated.isEmpty {
                Text("🌐 Traducción")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(translated)
                    .padding()
                    .background(color.opacity(0.1))
                    .cornerRadius(12)
            }

          
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button {
                    try? stt.start()
                } label: {
                    Label("Escuchar", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)

                Button {
                    stt.stop()
                } label: {
                    Label("Parar", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.callout)
                }
                .buttonStyle(.bordered)

                Button {
                    onTranslate()
                } label: {
                    Label("Traducir", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.callout)
                }
                .buttonStyle(.bordered)

                Button {
                    let toSpeak = translated.isEmpty ? original : translated
                    tts.speak(toSpeak, lang: langCode)
                } label: {
                    Label("Reproducir", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(.callout)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
            }

        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 4)
    }
}
