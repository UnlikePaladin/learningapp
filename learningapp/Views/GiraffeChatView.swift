import SwiftUI
import FoundationModels

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String

    enum Role { case user, lerny }
}

@Observable
final class GiraffeChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isStreaming: Bool = false
    var giraffeMood: GiraffeMood = .happy

    enum GiraffeMood: Equatable {
        case happy, talking, thinking, shrug
        var imageName: String {
            switch self {
            case .happy:    return "happy_giraffe"
            case .talking:  return "talk_giraffe"
            case .thinking: return "question_giraffe"
            case .shrug:    return "iguessbro_giraffe"
            }
        }
    }

    private var session = GiraffeChatViewModel.freshSession()

    private static func freshSession() -> LanguageModelSession {
        LanguageModelSession {
            "You are Lerny, a friendly and enthusiastic giraffe who loves helping students learn."
            "You are warm, encouraging, and patient. You use simple language and short sentences."
            "You occasionally make light giraffe references but don't overdo it."
            "When you don't know something, say so honestly. Never make up facts."
            "Keep responses concise — 2-4 sentences max unless the student asks for more detail."
        }
    }

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        inputText = ""

        messages.append(ChatMessage(role: .user, text: text))
        messages.append(ChatMessage(role: .lerny, text: ""))
        let replyIndex = messages.count - 1

        isStreaming = true
        giraffeMood = .thinking

        do {
            let stream = session.streamResponse(to: text)
            giraffeMood = .talking
            for try await snapshot in stream {
                messages[replyIndex].text = snapshot.content
            }
            giraffeMood = .happy
        } catch {
            messages[replyIndex].text = "Oops! My neck got tangled — something went wrong. Try again?"
            giraffeMood = .shrug
        }

        isStreaming = false
    }

    func reset() {
        session = GiraffeChatViewModel.freshSession()
        messages = []
        giraffeMood = .happy
    }
}

struct GiraffeChatView: View {
    @State private var vm = GiraffeChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                giraffeHeader

                Divider()

                messageList

                inputBar
            }
            .navigationTitle("Chat with Lerny")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Clear", action: vm.reset)
                        .font(.caption)
                        .disabled(vm.messages.isEmpty)
                }
            }
        }
    }

    private var giraffeHeader: some View {
        VStack(spacing: 8) {
            Image(vm.giraffeMood.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 130)
                .animation(.spring(duration: 0.3), value: vm.giraffeMood)

            if vm.messages.isEmpty {
                Text("Hi! I'm Lerny!\nAsk me anything about your lessons.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color("Lightgreen").opacity(0.3))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding()
            }
            .onChange(of: vm.messages.count) {
                withAnimation { proxy.scrollTo("bottom") }
            }
            .onChange(of: vm.messages.last?.text) {
                proxy.scrollTo("bottom")
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask Lerny something…", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { Task { await vm.send() } }

            Button {
                Task { await vm.send() }
            } label: {
                Image(systemName: vm.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(Color("Darkgreen"))
                    )
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .lerny {
                Image("normal_giraffe")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Spacer(minLength: 60)
            }

            Text(message.text.isEmpty ? " " : message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .lerny
                        ? Color("Lightgreen").opacity(0.6)
                        : Color("Darkgreen"),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .foregroundStyle(message.role == .lerny ? Color.primary : Color.white)
                .frame(maxWidth: .infinity, alignment: message.role == .lerny ? .leading : .trailing)

            if message.role == .user {
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    GiraffeChatView()
}
