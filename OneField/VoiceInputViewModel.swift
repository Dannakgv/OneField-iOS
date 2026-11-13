//
//  VoiceInputViewModel.swift
//  OneField
//
//  Created by Santiago Quihui on 06/10/25.
//

import SwiftUI
import Speech
import AVFoundation

@MainActor
@Observable
class VoiceInputViewModel {
    // MARK: - State Properties
    var isListening = false
    var showingPermissionAlert = false
    var speechAvailable = false
    
    // MARK: - Private Properties
    var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    init() {
        checkSpeechAvailability()
    }
    
    // MARK: - Public Methods
    func toggleVoiceInput(text: Binding<String>) {
        if isListening {
            stopListening()
        } else {
            startListening(text: text)
        }
    }
    
    func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    let granted = authStatus == .authorized
                    self.speechAvailable = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func checkSpeechAvailability() {
        speechAvailable = SFSpeechRecognizer.authorizationStatus() == .authorized && 
                         speechRecognizer?.isAvailable == true
    }
    
    func startListening(text: Binding<String>) {
        guard speechAvailable else {
            showingPermissionAlert = true
            return
        }
        
        guard !audioEngine.isRunning else { return }
        
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session configuration failed: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isListening = true
            
            // Start recognition task
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        text.wrappedValue = result.bestTranscription.formattedString
                        
                        if result.isFinal {
                            self.stopListening()
                        }
                    }
                    
                    if let error = error {
                        print("Speech recognition error: \(error)")
                        self.stopListening()
                    }
                }
            }
        } catch {
            print("Audio engine start failed: \(error)")
            stopListening()
        }
    } 
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session deactivation failed: \(error)")
        }
    }
}
