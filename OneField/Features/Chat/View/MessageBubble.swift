//
//  MessageBubble.swift
//  OneField
//
//  Created by Danna Valencia on 04/10/25.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: accessibilityEnabled ? 40 : 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: accessibilityEnabled ? 8 : 4) {
                // Message content
                Text(message.content)
                    .font(accessibilityEnabled ? .title3 : .body)
                    .padding(.horizontal, accessibilityEnabled ? 20 : 16)
                    .padding(.vertical, accessibilityEnabled ? 16 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: accessibilityEnabled ? 24 : 18)
                            .fill(message.isUser ? Color.accentColor : Color(.systemGray5))
                            .scaleEffect(isPressed && !accessibilityEnabled ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: reduceMotion ? 0.05 : 0.1), value: isPressed)
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .textSelection(.enabled) // Allow text selection
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(accessibilityEnabled ? .caption : .caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .accessibilityLabel("Sent \(formatTimeForAccessibility(message.timestamp))")
            }
            
            if !message.isUser {
                Spacer(minLength: accessibilityEnabled ? 40 : 60)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityActions {
            Button("Copy message") {
                copyToClipboard()
            }
            
            if !message.isUser {
                Button("Read aloud") {
                    // This would integrate with iOS speech synthesis if needed
                    // For now, VoiceOver handles reading
                }
            }
        }
        .onTapGesture {
            // Provide haptic feedback on tap
            if !accessibilityEnabled {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        }
        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 50) {
            copyToClipboard()
        } onPressingChanged: { pressing in
            if !accessibilityEnabled {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
        }
    }
    
    private var accessibilityLabel: String {
        let sender = message.isUser ? "You said" : "Assistant said"
        let time = formatTimeForAccessibility(message.timestamp)
        return "\(sender), \(message.content), sent \(time)"
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = message.content
        
        // Provide haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // Could show a toast or temporary message here if needed
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimeForAccessibility(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: now) {
            return "today at \(formatter.string(from: date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .day) {
            return "yesterday at \(formatter.string(from: date))"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateStyle = .medium
            dayFormatter.timeStyle = .short
            return dayFormatter.string(from: date)
        }
    }
}
