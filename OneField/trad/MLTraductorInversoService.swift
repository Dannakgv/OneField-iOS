//
//  MLTraductorInversoService.swift
//  OneField
//
//  Created by Angela Pesina on 10/10/25.
//

import CoreML

// modelo de traducción eng - esp
class MLTraductorInversoService {
    private let model: TraductorENtoES_1

    init?() {
        guard let loadedModel = try? TraductorENtoES_1(configuration: MLModelConfiguration()) else {
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
