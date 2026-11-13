//
//  TTSService.swift
//  OneField
//
//  Created by Angela Pesina on 08/10/25.
//

// Conversión de texto en audio — Text-to-Speech - Lectura en voz alta

import Foundation
import AVFoundation // audio, video y voz
import Combine // para que sea en timepo real

class TTSService: NSObject, ObservableObject {
    // motor de voz de apple, convierte texto a audio
    private let synth = AVSpeechSynthesizer()

    // Lectura del texto
    func speak(_ text: String, lang: String) {
        // evita que "hable" en los errores de silencios, etc
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // configuraciones de la voz
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        // rapidez de lectura, va de 0 (lento) a 1 (rápido)
        utterance.rate = 0.5
        // reproducción del texto
        synth.speak(utterance)
    }

    // para la lectura cuando termina la palabra actual
    func stop() {
        synth.stopSpeaking(at: .word)
    }
}
