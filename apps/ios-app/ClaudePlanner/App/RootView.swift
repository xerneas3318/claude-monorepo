import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        if let user = auth.user {
            TabView {
                TodayView(userId: user.uid)
                    .tabItem { Label("Today", systemImage: "checkmark.circle") }
                BrowseView(userId: user.uid)
                    .tabItem { Label("Browse", systemImage: "folder") }
            }
        } else {
            SignInView()
        }
    }
}
