import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var user: User?
    @Published var lastError: String?

    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()
        user = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.user = user }
        }
        if let u = user {
            print("[AuthService] already signed in uid=\(u.uid) providerData=\(u.providerData.map(\.providerID))")
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func startSignInWithApple(request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func completeSignInWithApple(result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            report("Apple authorization failed", error: error)
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let identityToken = credential.identityToken,
                let idTokenString = String(data: identityToken, encoding: .utf8)
            else {
                lastError = "Apple Sign In returned an unexpected payload."
                print("[AuthService] Missing credential/nonce/identityToken from Apple response")
                return
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            Auth.auth().signIn(with: firebaseCredential) { [weak self] result, error in
                Task { @MainActor in
                    if let error {
                        self?.report("Firebase signIn(with:) failed", error: error)
                    } else if let u = result?.user {
                        print("[AuthService] *** Firebase sign-in succeeded ***")
                        print("[AuthService]   uid   : \(u.uid)")
                        print("[AuthService]   email : \(u.email ?? "nil")")
                        print("[AuthService]   provs : \(u.providerData.map(\.providerID))")
                        self?.user = u
                    }
                }
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        user = nil
    }

    private func report(_ context: String, error: Error) {
        let ns = error as NSError
        print("""
        [AuthService] \(context)
          domain    : \(ns.domain)
          code      : \(ns.code)
          localized : \(ns.localizedDescription)
          userInfo  : \(ns.userInfo)
        """)
        lastError = "\(context): \(ns.localizedDescription) [\(ns.domain) #\(ns.code)]"
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
