import SwiftUI

extension View {
    func appNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemGray6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    func appNavigationTitle<ToolbarItems: ToolbarContent>(
        _ title: String,
        @ToolbarContentBuilder toolbarItems: @escaping () -> ToolbarItems
    ) -> some View {
        appNavigationTitle(title)
            .toolbar(content: toolbarItems)
    }

    func appNavigationStack(_ title: String) -> some View {
        NavigationStack {
            appNavigationTitle(title)
        }
    }

    func appNavigationStack<ToolbarItems: ToolbarContent>(
        _ title: String,
        @ToolbarContentBuilder toolbarItems: @escaping () -> ToolbarItems
    ) -> some View {
        NavigationStack {
            appNavigationTitle(title, toolbarItems: toolbarItems)
        }
    }
}
