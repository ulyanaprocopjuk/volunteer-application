import SwiftUI

enum HomeTab {
    case profile
    case map
    case explore
    case events
}

struct HomePageView: View {
    @ObservedObject var session: AppSession
    @StateObject private var profileModel: ProfileSetupViewModel

    @State private var selectedTab: HomeTab = .map
    @State private var isEditingProfile = false

    init(session: AppSession) {
        self.session = session
        _profileModel = StateObject(wrappedValue: ProfileSetupViewModel(session: session))
    }

    var body: some View {
        currentTabView
            .includeTabBar()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6).ignoresSafeArea())
            .overlay(alignment: .bottom) {
                BottomTabBar(selectedTab: $selectedTab)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .background(Color(.systemGray6).ignoresSafeArea())
            .task {
                await profileModel.loadMyProfileIfNeeded()
            }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .profile:
            if isEditingProfile {
                ProfileEditView(
                    viewModel: profileModel,
                    onBack: {
                        isEditingProfile = false
                    },
                    onSave: {
                        isEditingProfile = false
                    }
                )
            } else {
                ProfileView(
                    model: profileModel,
                    onEditProfile: {
                        isEditingProfile = true
                    },
                    onLogout: {
                        session.logout()
                    }
                )
            }

        case .map:
            MapEventsView(
                onNotificationsTap: {
                    // TODO: notifications
                }
            )

        case .explore:
            SearchEventsView()

        case .events:
            MyEventsView()
        }
    }
}

#Preview {
    HomePageView(session: AppSession())
}
