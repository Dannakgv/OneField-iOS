//
//  MLTraductorService.swift
//  OneField
//
//  Created by Angela Pesina on 10/10/25.
//

import CoreML

// modelo de traduccion esp -> eng 
class MLTraductorService {
    private let model: TraductorFrases

    init?() {
        guard let loadedModel = try? TraductorFrases(configuration: MLModelConfiguration()) else {
            return nil
        }
        self.model = loadedModel
    }

    func traducir(texto: String) -> String {
        guard let prediction = try? model.prediction(text: texto) else {
            return "[sin traducción]"
        }
        return prediction.label
    }
}
