import SwiftUI

struct AnalystScreen: View {
    @State private var messages: [AnalystChatMessage] = AnalystChatMessage.openingMessages
    @State private var messageText = ""
    @State private var isResponding = false
    @FocusState private var isComposerFocused: Bool

    private let chatService = AnalystChatService()
    private let samplePrompts = [
        "Is NVDA a buy?",
        "How is the S&P 500 doing today?",
        "What is the largest company by market cap?"
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(messages) { message in
                            AnalystMessageBubble(message: message)
                                .id(message.id)
                        }

                        promptChips
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture {
                    isComposerFocused = false
                }
                .onChange(of: messages) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: isResponding) { _, _ in
                    scrollToBottom(proxy)
                }
                .safeAreaInset(edge: .bottom) {
                    composer
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Analyst")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: startNewChat) {
                            Image(systemName: "square.and.pencil")
                        }
                        .disabled(isResponding)
                        .accessibilityLabel("New Chat")
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isComposerFocused = false
                        }
                    }
                }
            }
        }
    }

    private var promptChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(samplePrompts, id: \.self) { prompt in
                        Button {
                            messageText = prompt
                            isComposerFocused = true
                        } label: {
                            Text(prompt)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.background, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(.quaternary, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your analyst", text: $messageText, axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(1...5)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .submitLabel(.send)
                .onSubmit(sendMessage)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(canSend ? .blue : .gray.opacity(0.45), in: Circle())
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }

    private func startNewChat() {
        guard !isResponding else {
            return
        }

        messages = AnalystChatMessage.openingMessages
        messageText = ""
        isComposerFocused = false
    }

    private func sendMessage() {
        let question = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !question.isEmpty, !isResponding else {
            return
        }

        messages.append(AnalystChatMessage(role: .user, content: question))
        messageText = ""
        isComposerFocused = false
        isResponding = true

        let context = messages.map { message in
            AnalystChatContextMessage(role: message.role.contextRole, content: message.content)
        }

        let assistantMessage = AnalystChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)

        Task {
            do {
                for try await partialResponse in chatService.streamResponse(to: question, conversation: context) {
                    await MainActor.run {
                        updateMessage(id: assistantMessage.id, content: partialResponse)
                    }
                }

                await MainActor.run {
                    isResponding = false
                }
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription.isEmpty
                        ? "I couldn't reach the analyst model. Check Apple Intelligence availability, then try again."
                        : error.localizedDescription

                    updateMessage(id: assistantMessage.id, content: message)
                    isResponding = false
                }
            }
        }
    }

    private func updateMessage(id: UUID, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            return
        }

        messages[index].content = content
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.snappy) {
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
}

private struct AnalystMessageBubble: View {
    let message: AnalystChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user {
                Spacer(minLength: 44)
            }

            VStack(alignment: .leading, spacing: 7) {
                if message.role == .assistant {
                    Label("Analyst", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if message.content.isEmpty && message.role == .assistant {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundStyle(message.role == .user ? .white : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(message.role == .user ? Color.blue : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: message.role == .user ? 300 : .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 32)
            }
        }
    }
}

private struct AnalystChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: AnalystChatRole
    var content: String

    static let openingMessages = [
        AnalystChatMessage(
            role: .assistant,
            content: "Ask me about stocks, indexes, valuation, risk, catalysts, or market context. I’ll answer like a professional equity analyst and call out uncertainty clearly."
        )
    ]
}

private enum AnalystChatRole: Hashable {
    case user
    case assistant

    var contextRole: String {
        switch self {
        case .user: "User"
        case .assistant: "Analyst"
        }
    }
}

#Preview {
    AnalystScreen()
}
