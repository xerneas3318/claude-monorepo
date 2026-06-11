import FirebaseAuth
import Foundation

struct ClaudeMessage: Identifiable, Hashable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

enum RelayConfig {
    // Read at runtime from the Info.plist key `RelayBaseURL`. Set this in
    // `ios-app/project.yml` (info.properties.RelayBaseURL) before running
    // `xcodegen generate`. Kept out of source so the public repo doesn't
    // expose a specific deployment's domain.
    static let baseURL: URL = {
        let value = Bundle.main.object(forInfoDictionaryKey: "RelayBaseURL") as? String ?? ""
        guard let url = URL(string: value), !value.isEmpty, url.scheme?.hasPrefix("http") == true else {
            fatalError("RelayBaseURL not set in Info.plist. Configure it in project.yml and rerun xcodegen.")
        }
        return url
    }()
}

@MainActor
final class ClaudeClient: ObservableObject {
    @Published private(set) var messages: [ClaudeMessage] = []
    @Published private(set) var isSending: Bool = false
    @Published var errorMessage: String?

    // Opaque history blob the relay echoes back.
    private var wireHistory: [Any] = []

    /// Send a turn. Returns the assistant text on success (so callers can TTS it).
    @discardableResult
    func send(_ transcript: String, model: TalkModel, effort: TalkEffort) async -> String? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        messages.append(ClaudeMessage(role: .user, text: trimmed))
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            guard let user = Auth.auth().currentUser else { throw RelayError.notSignedIn }
            let bodyData = try JSONSerialization.data(withJSONObject: [
                "transcript": trimmed,
                "history": wireHistory,
                "model": model.wire,
                "effort": effort.rawValue,
            ], options: [])

            var attempt = 0
            var forceRefresh = false
            while true {
                attempt += 1
                let idToken = try await user.getIDToken(forcingRefresh: forceRefresh)
                var req = URLRequest(url: RelayConfig.baseURL.appendingPathComponent("talk"))
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                req.timeoutInterval = 300
                req.httpBody = bodyData

                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else {
                    throw RelayError.badResponse("Not an HTTP response")
                }
                // Stale-token recovery: one retry with a forced refresh.
                if http.statusCode == 401 && attempt == 1 {
                    forceRefresh = true
                    continue
                }
                guard (200..<300).contains(http.statusCode) else {
                    let body = String(data: data, encoding: .utf8) ?? "<binary>"
                    throw RelayError.badResponse("HTTP \(http.statusCode): \(body)")
                }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let reply = (json["reply"] as? String) ?? ""
                if let newHistory = json["history"] as? [Any] { wireHistory = newHistory }
                messages.append(ClaudeMessage(role: .assistant, text: reply))
                return reply
            }
        } catch {
            let detail: String
            if let urlErr = error as? URLError {
                detail = "\(urlErr.localizedDescription) (code \(urlErr.code.rawValue))"
            } else {
                detail = error.localizedDescription
            }
            print("[ClaudeClient] \(error)")
            errorMessage = detail
            return nil
        }
    }

    func reset() {
        messages.removeAll()
        wireHistory.removeAll()
        errorMessage = nil
    }
}

enum RelayError: LocalizedError {
    case notSignedIn
    case badResponse(String)
    var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in required."
        case .badResponse(let m): m
        }
    }
}
