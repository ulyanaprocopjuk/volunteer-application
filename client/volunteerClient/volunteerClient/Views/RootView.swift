import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        Group {
            switch session.flow {
            case .loading:
                ProgressView("Загрузка...")
            case .auth:
                NavigationStack {
                    LoginView(session: session)
                }
            case .profileSetup:
                NavigationStack {
                    ProfileSetupScreen(session: session)
                }
            case .main:
                NavigationStack {
                    MainPlaceholderView(onLogout: session.logout)
                }
            }
        }
    }
}

private struct ProfileSetupScreen: View {
    @ObservedObject var session: AppSession
    @StateObject private var viewModel: ProfileSetupViewModel

    init(session: AppSession) {
        self.session = session

        let profileAPI = ProfileAPI(
            baseURL: URL(string: AppConfig.baseURLString)!
        )

        _viewModel = StateObject(
            wrappedValue: ProfileSetupViewModel(
                session: session,
                api: profileAPI
            )
        )
    }

    var body: some View {
        ProfileSetupView(viewModel: viewModel)
    }
}

private struct MainPlaceholderView: View {
    let onLogout: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Главный экран")
                .font(.title2.bold())

            Text("Пока не реализован")
                .foregroundStyle(.secondary)

            Button("Выйти", action: onLogout)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
