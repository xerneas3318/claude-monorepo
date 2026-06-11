import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Text("ClaudePlanner")
                    .font(.largeTitle.bold())
                Text("Your Brain, in your pocket.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SignInWithAppleButton(
                onRequest: auth.startSignInWithApple(request:),
                onCompletion: auth.completeSignInWithApple(result:)
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 32)

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer().frame(height: 24)
        }
    }
}
