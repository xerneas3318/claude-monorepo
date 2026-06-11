import MarkdownUI
import SwiftUI

struct TalkView: View {
    @StateObject private var speech = SpeechRecognizer()
    @EnvironmentObject private var claude: ClaudeClient
    @EnvironmentObject private var tts: TTSService

    @AppStorage(TalkSettingsKey.model)  private var modelRaw: String  = TalkModel.sonnet.rawValue
    @AppStorage(TalkSettingsKey.effort) private var effortRaw: String = TalkEffort.medium.rawValue
    @AppStorage(TalkSettingsKey.speak)  private var speakReplies: Bool = false

    @State private var typedInput: String = ""
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

    private var model: TalkModel { TalkModel(rawValue: modelRaw) ?? .sonnet }
    private var effort: TalkEffort { TalkEffort(rawValue: effortRaw) ?? .medium }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversationList
                Divider()
                composer
            }
            .navigationTitle("Talk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        tts.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        speakReplies.toggle()
                        if !speakReplies { tts.stop() }
                    } label: {
                        Image(systemName: speakReplies
                              ? (tts.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                              : "speaker.slash")
                    }
                    .accessibilityLabel(speakReplies ? "Voice replies on" : "Voice replies off")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Talk settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        claude.reset(); speech.reset(); tts.stop()
                    } label: { Image(systemName: "trash") }
                    .disabled(claude.messages.isEmpty)
                }
            }
            .sheet(isPresented: $showSettings) {
                TalkSettingsSheet(
                    model: Binding(get: { model }, set: { modelRaw = $0.rawValue }),
                    effort: Binding(get: { effort }, set: { effortRaw = $0.rawValue }),
                    speakReplies: $speakReplies
                )
                .presentationDetents([.medium])
            }
        }
        .onDisappear { tts.stop() }
    }

    private var conversationList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if claude.messages.isEmpty {
                        ContentUnavailableView(
                            "Hold the mic to talk",
                            systemImage: "mic.circle",
                            description: Text("Try \"what's on my list today?\" or \"check off the first task.\"")
                        )
                        .padding(.top, 80)
                    } else {
                        ForEach(claude.messages) { msg in
                            messageBubble(msg).id(msg.id)
                        }
                    }
                    if claude.isSending {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Claude is thinking…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    if let err = claude.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: claude.messages.count) { _, _ in
                if let last = claude.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ msg: ClaudeMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 40) }
            Group {
                if msg.role == .assistant {
                    Markdown(msg.text)
                        .markdownTheme(.gitHub)
                        .textSelection(.enabled)
                } else {
                    Text(msg.text)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(msg.role == .user
                          ? Color.accentColor.opacity(0.18)
                          : Color.secondary.opacity(0.12))
            )
            .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
            if msg.role == .assistant { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if !speech.transcript.isEmpty {
                Text(speech.transcript)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            if let err = speech.errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            HStack(spacing: 12) {
                TextField("Type or hold the mic", text: $typedInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit(submitTyped)
                Button(action: submitTyped) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(typedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || claude.isSending)
                micButton
            }
            .padding(.horizontal)
            .padding(.bottom, 10)

            HStack(spacing: 6) {
                Image(systemName: "cpu").imageScale(.small)
                Text("\(model.displayName) · \(effort.displayName)")
                    .lineLimit(1)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private var micButton: some View {
        Image(systemName: speech.isRecording ? "mic.circle.fill" : "mic.circle")
            .font(.system(size: 36))
            .foregroundStyle(speech.isRecording ? Color.red : Color.accentColor)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !speech.isRecording { Task { await speech.start() } }
                    }
                    .onEnded { _ in
                        if speech.isRecording {
                            speech.stop()
                            let text = speech.transcript
                            speech.reset()
                            if !text.isEmpty { dispatch(text) }
                        }
                    }
            )
    }

    private func submitTyped() {
        let text = typedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        typedInput = ""
        dispatch(text)
    }

    private func dispatch(_ text: String) {
        let m = model
        let e = effort
        Task {
            let reply = await claude.send(text, model: m, effort: e)
            if speakReplies, let reply, !reply.isEmpty {
                tts.speak(reply)
            }
        }
    }
}

struct TalkSettingsSheet: View {
    @Binding var model: TalkModel
    @Binding var effort: TalkEffort
    @Binding var speakReplies: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    Picker("Model", selection: $model) {
                        ForEach(TalkModel.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Effort") {
                    Picker("Effort", selection: $effort) {
                        ForEach(TalkEffort.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    Toggle("Speak replies aloud", isOn: $speakReplies)
                } footer: {
                    Text("Uses Apple's on-device speech synthesis. No audio leaves the phone.")
                }
            }
            .navigationTitle("Talk settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
