import SwiftUI

enum TabBarLayout {
    static let height: CGFloat = 76
    static let contentSpacing: CGFloat = 18
}

private struct IncludeTabBarModifier: ViewModifier {
    let extraSpacing: CGFloat

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: TabBarLayout.height + extraSpacing)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func includeTabBar(extraSpacing: CGFloat = TabBarLayout.contentSpacing) -> some View {
        modifier(IncludeTabBarModifier(extraSpacing: extraSpacing))
    }
}
