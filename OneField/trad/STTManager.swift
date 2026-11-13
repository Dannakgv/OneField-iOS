//
//  STTManager.swift
//  OneField
//
//  Created by Angela Pesina on 08/10/25.
//

// Funciones de captura de audio y reconocimiento 

import Foundation
import Speech // para el reconocimiento de voz
import AVFoundation // audio
import Combine

@MainActor
class STTManager: NSObject, ObservableObject {
    private let audioEngine = AVAudioEngine() // audio del micro
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask? // reconoce idioma
    private(set) var recognizer: SFSpeechRecognizer

    @Published var transcript: String = "" // la transcripción

    // reconoce el idioma
    init(localeId: String) {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId))!
        super.init()
    }

    // pide todos los permisos
    func authorize() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    cont.resume(returning: ())
                case .denied:
                    cont.resume(throwing: NSError(domain: "STT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permiso de reconocimiento de voz denegado"]))
                case .restricted:
                    cont.resume(throwing: NSError(domain: "STT", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reconocimiento de voz restringido en este dispositivo"]))
                case .notDetermined:
                    cont.resume(throwing: NSError(domain: "STT", code: 3, userInfo: [NSLocalizedDescriptionKey: "Estado de permiso no determinado"]))
                @unknown default:
                    cont.resume(throwing: NSError(domain: "STT", code: 4, userInfo: [NSLocalizedDescriptionKey: "Estado de permiso desconocido"]))
                }
            }
        }
    }

    // sesión de audio
    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers, .allowBluetooth])
        try session.setActive(true)

        // texto en vivo
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        request?.requiresOnDeviceRecognition = true

        // se toma el input del micro
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        
        // prepara y enciende para empezar
        audioEngine.prepare()
        try audioEngine.start()
        
        // se actualiza el transcript con un mejor reconocimiento
        task = recognizer.recognitionTask(with: request!) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                self.transcript = r.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stop()
            }
        }
    }

        // detener las funciones 
    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
    }
    
    // cambiar el idioma del reconocimiento de voz sin recrear el objeto
    func updateLocale(_ newLocaleId: String) {
   
        stop()
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: newLocaleId))!
    }

}
