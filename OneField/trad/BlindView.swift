//  BlindView.swift
//  OneField
//
//  Created by Angela Pesina on 08/10/25.
//
 
// texto a voz

import SwiftUI

struct BlindView: View {
    @StateObject private var tts = TTSService()
    
    // modelos de CoreML que hice de traducción (esp -> eng) (eng -> esp)
    // funciona bien con los datos con los que se entrenó
    private let traductorESaEN = MLTraductorService()!
    private let traductorENaES = MLTraductorInversoService()!
    
    @State private var inputText: String = ""
    @State private var translatedText: String = ""
    @State private var isTranslationEnabled = false
    @State private var inputLanguage: InputLanguage = .spanish
    @State private var isLoadingTranslation = false
    @FocusState private var isFocused: Bool
    
    // se selecciona en que idioma es el input
    enum InputLanguage: String, CaseIterable, Identifiable {
        case spanish = "Español"
        case english = "Inglés"
        var id: String { rawValue }
        
        var code: String {
            switch self {
            case .spanish: return "es-MX"
            case .english: return "en-US"
            }
        }

        var opposite: InputLanguage {
            switch self {
            case .spanish: return .english
            case .english: return .spanish
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    
                    VStack(spacing: 6) {
                        Text("Texto a voz inteligente")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 30)
                        
                        Text("Escribe en el idioma que prefieras. Se traducirá automáticamente y podrás escucharlo en voz alta.")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundColor(.black.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    
                    //  idioma de entrada
                    VStack(spacing: 10) {
                        Label("Idioma del texto", systemImage: "character.book.closed")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Picker("Idioma del texto", selection: $inputLanguage) {
                            ForEach(InputLanguage.allCases) { lang in
                                Text(lang.rawValue).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 25)
                    }
                    
                        // texto
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Escribe el texto", systemImage: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.teal)
                        
                        TextEditor(text: $inputText)
                            .focused($isFocused)
                            .font(.system(size: 18, design: .rounded))
                            .frame(minHeight: 120, maxHeight: 200)
                            .padding(10)
                            .background(Color.gray.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.teal.opacity(0.3), lineWidth: 1))
                    }
                    .padding(.horizontal, 25)
                    
                    // traducción automática al idioma contrario
                    Toggle(isOn: $isTranslationEnabled) {
                        Label("Mostrar traducción al idioma contrario", systemImage: "globe")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .padding(.horizontal, 25)
                    
                    if isTranslationEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Traducción generada", systemImage: "text.bubble.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.purple)
                                .padding(.leading, 25)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.gray.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                                
                                if isLoadingTranslation {
                                    ProgressView("Traduciendo…")
                                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                } else {
                                    Text(translatedText.isEmpty ? "— Traducción aparecerá aquí..." : translatedText)
                                        .font(.system(size: 20, design: .rounded))
                                        .foregroundColor(.black)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(minHeight: 80)
                            .padding(.horizontal, 25)
                        }
                        .animation(.easeInOut(duration: 0.3), value: translatedText)
                    }
                    
                    // lectura en voz alta
                    Button {
                        let textToSpeak = isTranslationEnabled && !translatedText.isEmpty ? translatedText : inputText
                        let langCode = isTranslationEnabled && !translatedText.isEmpty
                            ? inputLanguage.opposite.code
                            : inputLanguage.code
                        tts.speak(textToSpeak, lang: langCode)
                    } label: {
                        Label("Leer en voz alta", systemImage: "speaker.wave.3.fill")
                            .font(.system(size: 18, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .padding(.horizontal, 25)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Spacer()
                }
                .padding(.bottom, 60)
            }
        }
        .onChange(of: inputText) { _, newText in
            Task { await autoTranslateIfNeeded(text: newText) }
        }
        .onChange(of: inputLanguage) { _, _ in
            translatedText = ""
            Task { await autoTranslateIfNeeded(text: inputText) }
        }
        .onChange(of: isTranslationEnabled) { _, enabled in
            if !enabled {
                translatedText = ""
            } else {
                Task { await autoTranslateIfNeeded(text: inputText) }
            }
        }
    }

     // usar los modelos core ml para la traducción
    private func autoTranslateIfNeeded(text: String) async {
        guard isTranslationEnabled else { return }
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanText.isEmpty else {
            translatedText = ""
            return
        }

        isLoadingTranslation = true
        defer { isLoadingTranslation = false }

        translatedText = inputLanguage == .spanish
            ? traductorESaEN.traducir(texto: cleanText)
            : traductorENaES.traducir(texto: cleanText)
    }
}
