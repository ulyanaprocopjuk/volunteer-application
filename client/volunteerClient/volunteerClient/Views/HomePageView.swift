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
    @State private var isMenuPresented = false

    init(session: AppSession) {
        self.session = session
        _profileModel = StateObject(wrappedValue: ProfileSetupViewModel(session: session))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            currentTabView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6).ignoresSafeArea())
                .overlay(alignment: .bottom) {
                    BottomTabBar(selectedTab: $selectedTab)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .disabled(isMenuPresented)
                .blur(radius: isMenuPresented ? 2 : 0)
                .animation(.easeInOut(duration: 0.22), value: isMenuPresented)

            if isMenuPresented {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeMenu()
                    }
                    .transition(.opacity)
                    .zIndex(1)

                HomeSideMenuView(
                    onClose: { closeMenu() },
                    onOpenProfile: {
                        selectedTab = .profile
                        closeMenu()
                    },
                    onOpenMap: {
                        selectedTab = .map
                        closeMenu()
                    },
                    onOpenExplore: {
                        selectedTab = .explore
                        closeMenu()
                    },
                    onOpenEvents: {
                        selectedTab = .events
                        closeMenu()
                    }
                )
                .frame(width: 280)
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.22), value: isMenuPresented)
        .task {
            await profileModel.loadMyProfileIfNeeded()
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case .profile:
            ProfileView(
                model: profileModel,
                onLogout: {
                    session.logout()
                }
            )

        case .map:
            MapEventsView(
                onMenuTap: { isMenuPresented = true },
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

    private func closeMenu() {
        isMenuPresented = false
    }
}

#Preview {
    HomePageView(session: AppSession())
}
