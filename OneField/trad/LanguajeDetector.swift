//
//  LanguajeDetector.swift
//  OneField
//
//  Created by Angela Pesina on 08/10/25.
//

// Detección de idioma, lo uso para detectar el cambio de idioma en el speech to text 

import Foundation
import NaturalLanguage // procesa lenguaje natural

// definir los códigos de idioma
enum LangCode: String { case es = "es", en = "en" }

struct DetectedLanguage {
    let code: String; // detecta el código del idioma
    let confidence: Double } // confianza del modelo (0-1)

enum LanguageDetector {
    static func detectCode(for text: String) -> DetectedLanguage? {
        // reconoce el idioma
        let recognizer = NLLanguageRecognizer()
        // se le da el texto a analizar
        recognizer.processString(text)
        // detecta el idioma dominante
        guard let lang = recognizer.dominantLanguage else { return nil }
        // calcula el nivel de confianza de la traducción
        let conf = recognizer.languageHypotheses(withMaximum: 1)[lang] ?? 0
        // devuelve el resultado traducido 
        return DetectedLanguage(code: lang.rawValue, confidence: Double(conf))
    }
}

