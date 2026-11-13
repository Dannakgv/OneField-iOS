//
//  AccessibleInputView.swift
//  OneField
//
//  Created by Santiago Quihui on 06/10/25.
//

import SwiftUI
import Speech
import AVFoundation

struct AccessibleInputView: View {
    @Binding var text: String
    @Binding var isResponding: Bool
    @FocusState.Binding var isInputFocused: Bool
    
    let onSend: () -> Void
    let placeholder: String
    
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var voiceInputViewModel = VoiceInputViewModel()
    
    var body: some View {
        VStack(spacing: accessibilityEnabled ? 16 : 12) {
            // Voice input button (prominent for accessibility users)
            if accessibilityEnabled || voiceOverEnabled {
                Button(action: { voiceInputViewModel.toggleVoiceInput(text: $text) }) {
                    HStack(spacing: 12) {
                        Image(systemName: voiceInputViewModel.isListening ? "mic.fill" : "mic")
                            .font(.title2)
                        Text(voiceInputViewModel.isListening ? "Stop Listening" : "Speak Your Question")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(voiceInputViewModel.isListening ? Color.red.opacity(0.2) : Color.accentColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        voiceInputViewModel.isListening ? Color.red : Color.accentColor,
                                        lineWidth: 2
                                    )
                            )
                    )
                    .foregroundColor(voiceInputViewModel.isListening ? .red : .accentColor)
                }
                .disabled(isResponding || !voiceInputViewModel.speechAvailable)
                .accessibilityLabel(voiceInputViewModel.isListening ? "Stop voice input" : "Start voice input")
                .accessibilityHint(voiceInputViewModel.isListening ? "Stops listening to your voice" : "Starts listening for your voice input")
                .scaleEffect(voiceInputViewModel.isListening ? 1.02 : 1.0)
                .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.2), value: voiceInputViewModel.isListening)
            }
            
            // Text input area
            HStack(spacing: accessibilityEnabled ? 16 : 12) {
                HStack(spacing: 8) {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .font(accessibilityEnabled ? .title3 : .body)
                        .accessibilityLabel("Message input")
                        .accessibilityHint("Type your question or use voice input")
                        .onSubmit {
                            onSend()
                        }
                    
                    if isInputFocused && !text.isEmpty {
                        Button(action: { text = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(accessibilityEnabled ? .title3 : .body)
                        }
                        .accessibilityLabel("Clear text")
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, accessibilityEnabled ? 20 : 16)
                .padding(.vertical, accessibilityEnabled ? 16 : 12)
                .background(
                    RoundedRectangle(cornerRadius: accessibilityEnabled ? 28 : 20)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: accessibilityEnabled ? 28 : 20)
                                .strokeBorder(
                                    isInputFocused ? Color.accentColor.opacity(0.3) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
                .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.2), value: isInputFocused)
                
                // Send button - larger for accessibility
                Button(action: onSend) {
                    ZStack {
                        Circle()
                            .fill(canSendMessage ? Color.accentColor : Color(.tertiarySystemBackground))
                            .frame(
                                width: accessibilityEnabled ? 52 : 36, 
                                height: accessibilityEnabled ? 52 : 36
                            )
                        
                        Image(systemName: isResponding ? "stop.circle" : "arrow.up")
                            .font(.system(
                                size: accessibilityEnabled ? 20 : 16, 
                                weight: .semibold
                            ))
                            .foregroundColor(canSendMessage ? .white : .secondary)
                    }
                }
                .disabled(!canSendMessage && !isResponding)
                .accessibilityLabel(isResponding ? "Stop generating response" : "Send message")
                .accessibilityHint(isResponding ? "Stops the AI from generating a response" : "Sends your message to the AI assistant")
                .scaleEffect(canSendMessage || isResponding ? 1.0 : 0.8)
                .animation(.spring(response: reduceMotion ? 0.1 : 0.3, dampingFraction: 0.7), value: canSendMessage)
                
                // Voice input button for regular UI (smaller)
                if !accessibilityEnabled && !voiceOverEnabled && voiceInputViewModel.speechAvailable {
                    Button(action: toggleVoiceInput) {
                        Image(systemName: voiceInputViewModel.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(voiceInputViewModel.isListening ? .red : .secondary)
                            .padding(8)
                            .background(
                                Circle().fill(
                                    voiceInputViewModel.isListening ? Color.red.opacity(0.1) : Color(.tertiarySystemBackground)
                                )
                            )
                    }
                    .disabled(isResponding)
                    .accessibilityLabel(voiceInputViewModel.isListening ? "Stop voice input" : "Start voice input")
                    .scaleEffect(voiceInputViewModel.isListening ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: voiceInputViewModel.isListening)
                }
            }
            
            // Listening indicator
            if voiceInputViewModel.isListening {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: voiceInputViewModel.isListening)
                    
                    Text("Listening... Speak now")
                        .font(accessibilityEnabled ? .title3 : .caption)
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Currently listening for voice input")
            }
        }
        .onAppear {
            checkSpeechPermission()
        }
        .alert("Microphone Permission Required", isPresented: $voiceInputViewModel.showingPermissionAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To use voice input, please enable microphone access in Settings.")
        }
    }
    
    private var canSendMessage: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }
    
    private func checkSpeechPermission() {
        Task {
            let authStatus = SFSpeechRecognizer.authorizationStatus()
            
            await MainActor.run {
                voiceInputViewModel.speechAvailable = voiceInputViewModel.speechRecognizer?.isAvailable == true && authStatus == .authorized
            }
        }
    }
    
    private func toggleVoiceInput() {
        if voiceInputViewModel.isListening {
            voiceInputViewModel.stopListening()
        } else {
            voiceInputViewModel.startListening(text: $text)
        }
    }
}


