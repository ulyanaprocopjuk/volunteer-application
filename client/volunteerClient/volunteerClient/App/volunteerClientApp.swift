import SwiftUI

@main
struct LocalAuthApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "volunteerapp" else { return }
        guard url.host == "reset-password" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let token = components?.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else { return }

        session.pendingPasswordResetToken = token
    }
}
