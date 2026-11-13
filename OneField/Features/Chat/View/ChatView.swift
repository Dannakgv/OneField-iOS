//
//  ChatView.swift
//  OneField
//
//  Created by Danna Valencia on 04/10/25.
//
import SwiftUI
import FoundationModels
import HealthKit

@Generable(description: "A health data response that interprets user metrics")
struct HealthDataResponse {
    @Guide(description: "The main explanation of the user's data")
    var explanation: String
    
    @Guide(description: "Key insights about trends or patterns")
    var insights: String
}

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    @Environment(\.accessibilityLargeContentViewerEnabled) private var largeContentViewerEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.softLavender.opacity(0.9), .lightBackground]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    modelStatusView
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                        .accessibilityHidden(true)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: accessibilityEnabled ? 20 : 12) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if viewModel.isResponding {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(accessibilityEnabled ? 1.2 : 0.8)
                                        Text("Thinking...")
                                            .font(accessibilityEnabled ? .title3 : .caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .id("thinking")
                                }
                            }
                            .padding(.horizontal, accessibilityEnabled ? 20 : 16)
                            .padding(.bottom, isInputFocused ? 8 : 16)
                        }
                        .onTapGesture { isInputFocused = false }
                        .onChange(of: viewModel.messages.count) { _ in scrollToBottom(proxy: proxy) }
                        .onChange(of: viewModel.isResponding) { if $0 { scrollToThinking(proxy: proxy) } }
                        .onChange(of: isInputFocused) { if $0 { scrollToBottomWithDelay(proxy: proxy) } }
                    }
                    
                    AccessibleInputView(
                        text: $viewModel.inputText,
                        isResponding: $viewModel.isResponding,
                        isInputFocused: $isInputFocused,
                        onSend: viewModel.sendMessage,
                        placeholder: "Ask about your health..."
                    )
                    .padding(.horizontal, accessibilityEnabled ? 20 : 16)
                    .padding(.vertical, accessibilityEnabled ? 16 : 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: -2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            }
            .navigationTitle("Health Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: HealthDataPreviewView()) {
                        Label("Health Data", systemImage: "heart.text.square")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear Chat", systemImage: "trash") {
                            viewModel.clearChat()
                        }
                        .disabled(viewModel.messages.isEmpty || viewModel.isResponding)
                        
                        if viewModel.shouldShowHealthSettings {
                            Button("Health Settings", systemImage: "gear") {
                                viewModel.openHealthSettings()
                            }
                        }
                        
                        Button("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down") {
                            isInputFocused = false
                        }
                    } label: {
                        Label("More options", systemImage: "ellipsis.circle")
                    }
                }
            }
            .alert("Health Data Access", isPresented: $viewModel.showingHealthAlert) {
                Button("Open Settings") { viewModel.launchHealthSettings() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To access your health data, please enable permissions in the Health app settings.")
            }
        }
    }
    
    @ViewBuilder
    private var modelStatusView: some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(viewModel.modelStatusColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.modelStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Circle()
                    .fill(viewModel.healthKitStatusColor)
                    .frame(width: 8, height: 8)
                Text(viewModel.healthKitStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                
                if viewModel.canRequestHealthPermissions {
                    Button("Enable Health") {
                        Task { await viewModel.requestHealthAuthorization() }
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .tint(.brightPurple)
                    .controlSize(.mini)
                } else if viewModel.shouldShowHealthSettings {
                    Button("Settings") { viewModel.openHealthSettings() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        let animation: Animation = reduceMotion ? .linear(duration: 0.1) : .easeOut(duration: 0.3)
        withAnimation(animation) {
            if let lastMessageId = viewModel.messages.last?.id {
                proxy.scrollTo(lastMessageId, anchor: .bottom)
            } else if viewModel.isResponding {
                proxy.scrollTo("thinking", anchor: .bottom)
            }
        }
    }

    private func scrollToThinking(proxy: ScrollViewProxy) {
        let animation: Animation = reduceMotion ? .linear(duration: 0.1) : .easeOut(duration: 0.3)
        withAnimation(animation) {
            proxy.scrollTo("thinking", anchor: .bottom)
        }
    }

    private func scrollToBottomWithDelay(proxy: ScrollViewProxy) {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastMessageId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastMessageId, anchor: .bottom)
                    } else if viewModel.isResponding {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
    }
}
