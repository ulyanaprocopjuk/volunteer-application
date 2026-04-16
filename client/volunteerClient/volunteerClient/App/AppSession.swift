import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    enum Flow {
        case loading
        case auth
        case profileSetup
        case main
        case admin
    }

    enum PostAuthDestination {
        case profileSetup
        case main
    }

    @Published private(set) var flow: Flow = .loading
    @Published private(set) var token: String?
    @Published private(set) var currentUser: UserResponse?
    @Published var globalError: String?

    private let authAPI: AuthAPIProtocol
    private let keychain: KeychainStorage
    private let installState: InstallState

    init(
        authAPI: AuthAPIProtocol? = nil,
        keychain: KeychainStorage? = nil,
        installState: InstallState? = nil
    ) {
        self.authAPI = authAPI ?? AuthAPI()
        self.keychain = keychain ?? KeychainStorage()
        self.installState = installState ?? InstallState()

        handleFreshInstallIfNeeded()

        Task {
            await restoreSession()
        }
    }

    func restoreSession() async {
        flow = .loading
        globalError = nil

        do {
            guard let savedToken = try keychain.loadToken(), !savedToken.isEmpty else {
                token = nil
                currentUser = nil
                flow = .auth
                return
            }

            let user = try await authAPI.getCurrentUser(token: savedToken)
            token = savedToken
            currentUser = user
            flow = user.role == .admin ? .admin : .main
        } catch {
            clearSessionState()
            globalError = error.localizedDescription
            flow = .auth
        }
    }

    func authorize(with token: String, destination: PostAuthDestination) async throws {
        let user = try await authAPI.getCurrentUser(token: token)

        try keychain.saveToken(token)

        self.token = token
        self.currentUser = user
        self.globalError = nil

        if user.role == .admin {
            flow = .admin
        } else {
            switch destination {
            case .profileSetup:
                flow = .profileSetup
            case .main:
                flow = .main
            }
        }
    }

    func completeProfileSetup() {
        flow = .main
    }

    func logout() {
        clearSessionState()
        globalError = nil
        flow = .auth
    }

    var isAuthenticated: Bool {
        token != nil && currentUser != nil
    }

    private func handleFreshInstallIfNeeded() {
        guard installState.isFreshInstall() else { return }

        do {
            try keychain.clearToken()
        } catch {
            globalError = error.localizedDescription
        }
    }

    private func clearSessionState() {
        do {
            try keychain.clearToken()
        } catch {
            globalError = error.localizedDescription
        }

        token = nil
        currentUser = nil
    }
}
