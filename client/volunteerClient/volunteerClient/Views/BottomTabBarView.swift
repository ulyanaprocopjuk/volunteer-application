import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: HomeTab

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                tabButton(.profile, icon: "person.crop.circle")
                Spacer()
                tabButton(.map, icon: "globe.europe.africa")
                Spacer()
                tabButton(.explore, icon: "magnifyingglass")
                Spacer()
                tabButton(.events, icon: "calendar")
            }
            .padding(.horizontal, 30)
            .frame(height: TabBarLayout.height)
            .background(Color.white)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func tabButton(_ tab: HomeTab, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        selectedTab == tab
                        ? Color(red: 0.09, green: 0.60, blue: 0.93)
                        : Color.gray
                    )

                Circle()
                    .fill(
                        selectedTab == tab
                        ? Color(red: 0.09, green: 0.60, blue: 0.93)
                        : .clear
                    )
                    .frame(width: 6, height: 6)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

}
