import Foundation

// Shared app-level state for cross-screen navigation requests. Used by
// AppIntent invocations (Lock Screen widget, Siri, Action button, deep link)
// to ask the UI to surface the Talk to Claude sheet.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var showTalk: Bool = false

    func requestTalk() { showTalk = true }
}
