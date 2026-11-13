//
//  ChatViewModel.swift
//  OneField
//
//  Created by Danna Valencia on 06/10/25.
//

import SwiftUI
import FoundationModels
import HealthKit

@MainActor
@Observable
class ChatViewModel {
    // MARK: - State Properties
    var messages: [Message] = []
    var inputText = ""
    var isResponding = false
    var showingHealthAlert = false
    
    // MARK: - Dependencies
    private let healthKitManager: HealthKitManager
    private let model = SystemLanguageModel.default
    private let session: LanguageModelSession
    
    // MARK: - Initialization
    init() {
        self.healthKitManager = HealthKitManager()
        self.session = LanguageModelSession(
            tools: [HealthKitTool()], 
            instructions: """
            You help users view recorded activity metrics and general wellness information.
            Report only the measurements actually returned by HealthKit. Missing records do not mean zero.
            Keep factual readings separate from general educational information.
            Do not diagnose conditions, prescribe treatment, or infer that a measurement is normal or abnormal.
            Do not claim to have read data unless a query returned it.
            """
        )
        
        addWelcomeMessage()
    }
    
    // MARK: - Public Methods
    func sendMessage() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty, !isResponding else { return }
        
        // Add user message
        let userMessage = Message(content: trimmedInput, isUser: true)
        messages.append(userMessage)
        
        // Clear input
        inputText = ""
        
        // Reserve the request before starting the asynchronous task.
        isResponding = true

        // Generate response
        Task {
            await generateResponse(to: trimmedInput)
        }
    }
    
    func clearChat() {
        messages.removeAll()
        addWelcomeMessage()
    }
    
    func openHealthSettings() {
        showingHealthAlert = true
    }
    
    func launchHealthSettings() {
        healthKitManager.openHealthSettings()
    }

    // MARK: - Computed Properties
    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }
    
    var modelStatusColor: Color {
        switch model.availability {
        case .available:
            return .green
        case .unavailable:
            return .red
        }
    }
    
    var modelStatusText: String {
        switch model.availability {
        case .available:
            return "Model Available"
        case .unavailable(.deviceNotEligible):
            return "Device not eligible for Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence not enabled"
        case .unavailable(.modelNotReady):
            return "Model downloading or not ready"
        case .unavailable(let other):
            return "Model unavailable: \(other)"
        }
    }
    
    var healthKitStatusColor: Color {
        if !healthKitManager.isAvailable {
            return .orange
        }
        
        switch healthKitManager.authorizationStatus {
        case .requestCompleted:
            return .green
        case .requestFailed:
            return .red
        case .notDetermined:
            return .yellow
        }
    }
    
    var healthKitStatusText: String {
        if !healthKitManager.isAvailable {
            return "HealthKit not available"
        }
        
        switch healthKitManager.authorizationStatus {
        case .requestCompleted:
            return "Health permission request completed"
        case .requestFailed:
            return "Health permission request failed"
        case .notDetermined:
            return "Health access not set"
        }
    }
    
    // MARK: - Health Kit Integration
    func requestHealthAuthorization() async {
        await healthKitManager.requestAuthorization()
    }
    
    var shouldShowHealthSettings: Bool {
        healthKitManager.shouldShowSettingsAlert()
    }
    
    var canRequestHealthPermissions: Bool {
        healthKitManager.canRequestPermissions()
    }
    
    // MARK: - Private Methods
    private func addWelcomeMessage() {
        let welcomeMessage = switch model.availability {
        case .available:
            if healthKitManager.authorizationStatus == .requestCompleted {
                "Hello! I'm your local AI assistant powered by Apple Intelligence. I can read the health data you choose to share. I can help answer questions about your heart rate, steps, activity, and more. How can I help you today?"
            } else {
                "Hello! I'm your local AI assistant powered by Apple Intelligence. I can help with general questions, and if you enable health data access, I can also provide insights about your health metrics. How can I help you today?"
            }
        case .unavailable(.deviceNotEligible):
            "This device doesn't support Apple Intelligence. The chat functionality requires a compatible device."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Please enable Apple Intelligence in Settings to use the chat feature."
        case .unavailable(.modelNotReady):
            "The AI model is currently downloading or preparing. Please try again in a moment."
        case .unavailable(let other):
            "The AI model is currently unavailable (\(other)). Please try again later."
        }
        
        messages.append(Message(content: welcomeMessage, isUser: false))
    }
    
    private func generateResponse(to prompt: String) async {
        defer { isResponding = false }

        if let information = Self.heatHydrationInformation(for: prompt) {
            messages.append(Message(content: information, isUser: false))
            return
        }

        // Step totals are a database lookup, so they do not require generation.
        let words = Set(prompt.lowercased().split { !$0.isLetter }.map(String.init))
        if !words.isDisjoint(with: ["step", "steps", "paso", "pasos"]) {
            if healthKitManager.authorizationStatus != .requestCompleted {
                guard await healthKitManager.requestAuthorization() else {
                    messages.append(Message(content: "I couldn't request Health access. Please try Enable Health again.", isUser: false))
                    return
                }
            }
            do {
                let result = try await healthKitManager.queryStepCount(for: prompt)
                messages.append(Message(content: result, isUser: false))
            } catch HealthKitError.noData {
                messages.append(Message(content: "No step data is available for that period. There may be no records, or step access may be disabled. Check OneField's permissions in the Health app.", isUser: false))
            } catch {
                let detail = error as NSError
                print("Step query failed [\(detail.domain):\(detail.code)]: \(detail.localizedDescription)")
                messages.append(Message(content: "I couldn't read steps from Health. \(detail.localizedDescription) Open Health to check that step records exist and OneField can read them.", isUser: false))
            }
            return
        }

        guard case .available = model.availability else {
            messages.append(Message(content: "The AI model is unavailable right now. You can still ask for your step count.", isUser: false))
            return
        }

        if containsHealthQuery(prompt) && healthKitManager.authorizationStatus != .requestCompleted {
            messages.append(Message(content: "Please enable Health access before asking about your personal health data.", isUser: false))
            return
        }

        do {
            // First, check if this is a health-related query
            var enhancedPrompt = prompt
            var healthContext = ""
            
            // Check for health-related queries and get relevant data
            if containsHealthQuery(prompt) && healthKitManager.authorizationStatus == .requestCompleted {
                do {
                    healthContext = try await healthKitManager.queryHealthData(for: prompt)
                    if !healthContext.isEmpty {
                        enhancedPrompt = """
                        User question: \(prompt)
                        
                        User's Personal Data from HealthKit:
                        \(healthContext)
                        
                        Please analyze and explain this personal data to help the user understand their metrics. Focus on interpreting the numbers and patterns shown above.
                        """
                    }
                } catch {
                    healthContext = "I couldn't retrieve your health data: \(error.localizedDescription)"
                    enhancedPrompt = "\(prompt)\n\nNote: \(healthContext)"
                }
            } else if containsHealthQuery(prompt) && healthKitManager.authorizationStatus != .requestCompleted {
                healthContext = "I don't have access to your health data. Please enable health data access to get personalized health insights."
                enhancedPrompt = "\(prompt)\n\nNote: \(healthContext)"
            }
            
            // Try guided generation for health queries with data
            if containsHealthQuery(prompt) && !healthContext.isEmpty && healthKitManager.authorizationStatus == .requestCompleted {
                do {
                    let guidedResponse = try await session.respond(to: enhancedPrompt, generating: HealthDataResponse.self)
                    
                    let formattedResponse = """
                    \(guidedResponse.content.explanation)
                    
                    \(guidedResponse.content.insights)
                    """
                    let assistantMessage = Message(content: formattedResponse, isUser: false)
                    messages.append(assistantMessage)
                    
                    // Early return to avoid the regular streaming below
                    isResponding = false
                    return
                } catch LanguageModelSession.GenerationError.guardrailViolation(let context) {
                    throw LanguageModelSession.GenerationError.guardrailViolation(context)
                } catch LanguageModelSession.GenerationError.refusal(let refusal, let context) {
                    throw LanguageModelSession.GenerationError.refusal(refusal, context)
                } catch {
                    // Fall through to regular streaming if guided generation fails
                    print("Guided generation failed, falling back to streaming: \(error)")
                }
            }
            
            // Stream the response for a more interactive experience
            let stream = session.streamResponse(to: enhancedPrompt)
            var accumulatedResponse = ""
            var currentMessageIndex: Int?
            
            for try await partial in stream {
                // For string responses, the partial content is available directly
                let content = partial.content
                if !content.isEmpty {
                    accumulatedResponse = content
                    
                    if let index = currentMessageIndex {
                        // Update existing message
                        messages[index] = Message(content: accumulatedResponse, isUser: false)
                    } else {
                        // Add new message
                        let assistantMessage = Message(content: accumulatedResponse, isUser: false)
                        messages.append(assistantMessage)
                        currentMessageIndex = messages.count - 1
                    }
                }
            }
            
            // If streaming didn't work, fall back to regular response
            if accumulatedResponse.isEmpty {
                let response = try await session.respond(to: enhancedPrompt)
                let assistantMessage = Message(content: response.content, isUser: false)
                messages.append(assistantMessage)
            }
            
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            messages.append(Message(content: "Apple Intelligence couldn't answer this health question. I can show recorded measurements, but personalized medical guidance needs a healthcare professional.", isUser: false))
        } catch LanguageModelSession.GenerationError.refusal {
            messages.append(Message(content: "Apple Intelligence can't provide that guidance. You can ask for recorded measurements such as today's steps.", isUser: false))
        } catch {
            print("Chat generation failed: \(error)")
            let errorMessage = Message(
                content: "I couldn't generate a response right now. Please try again.",
                isUser: false
            )
            messages.append(errorMessage)
        }
        
        isResponding = false
    }
    
    // Reviewed educational content; independent of model availability and Health permissions.
    static func heatHydrationInformation(for prompt: String) -> String? {
        let text = prompt.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let words = Set(text.split { !$0.isLetter }.map(String.init))
        let hydration = !words.isDisjoint(with: ["water", "hydration", "hydrate", "agua", "hidratacion", "hidratarme"])
        let heat = !words.isDisjoint(with: ["heat", "hot", "calor"])
        guard hydration && heat else { return nil }
        // Source: CDC/NIOSH heat hydration guidance. Reviewed November 2026.
        if !words.isDisjoint(with: ["agua", "calor", "hidratacion", "hidratarme"]) {
            return """
            Con calor, bebe agua regularmente, sin esperar a tener sed, y descansa en un lugar fresco. No hay una frecuencia única para todos: depende de la actividad, la sudoración y tus condiciones de salud. Si tienes una restricción de líquidos, sigue las indicaciones de tu profesional de salud.

            Fuente: CDC — https://www.cdc.gov/niosh/heat-stress/recommendations/index.html
            """
        }
        return """
        In hot weather, drink water regularly before you feel thirsty and take breaks in a cool place. There isn't one schedule for everyone: needs depend on activity, sweating, and health conditions. If you have a fluid restriction, follow your healthcare professional's guidance.

        Source: CDC — https://www.cdc.gov/niosh/heat-stress/recommendations/index.html
        """
    }

    private func containsHealthQuery(_ prompt: String) -> Bool {
        let healthKeywords = [
            // Fitness metrics
            "heart rate", "heartrate", "heart", "pulse", "bpm",
            "steps", "walking", "activity", "exercise", "workout", "fitness",
            "calories", "energy", "burned", "active energy", "resting energy",
            
            // Sleep and recovery
            "sleep", "rest", "recovery", "bedtime",
            
            // Biometrics
            "weight", "height", "blood pressure", "oxygen", "body",
            "heart rate variability", "hrv", "resting heart rate",
            
            // General health tracking
            "health", "data", "metrics", "tracking", "trends", "stats",
            "average", "maximum", "minimum", "daily", "weekly", "monthly",
            
            // Activity-specific
            "distance", "pace", "speed", "elevation", "floors", "flights",
            "stand", "standing", "move", "movement"
        ]
        
        let lowercasePrompt = prompt.lowercased()
        return healthKeywords.contains { keyword in
            lowercasePrompt.contains(keyword)
        }
    }
}
