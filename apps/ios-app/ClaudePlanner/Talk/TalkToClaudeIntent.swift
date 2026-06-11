import AppIntents

struct TalkToClaudeIntent: AppIntent {
    static var title: LocalizedStringResource = "Talk to Claude"
    static var description = IntentDescription(
        "Open ClaudePlanner and start a voice conversation with Claude."
    )

    // Forces the app to foreground when the intent runs. Required so the
    // microphone (which can only be used by a foregrounded app) becomes
    // available immediately.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.requestTalk()
        return .result()
    }
}

struct ClaudePlannerShortcuts: AppShortcutsProvider {
    // Siri matches phrases that include `${applicationName}`. Provide multiple
    // permutations so casual phrasing ("talk to claude", "open claude") works.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TalkToClaudeIntent(),
            phrases: [
                "Talk to Claude in \(.applicationName)",
                "Talk in \(.applicationName)",
                "Open Talk to Claude in \(.applicationName)",
                "Open \(.applicationName) talk",
                "Start \(.applicationName)",
                "Ask Claude in \(.applicationName)",
            ],
            shortTitle: "Talk to Claude",
            systemImageName: "mic.circle.fill"
        )
    }
}
