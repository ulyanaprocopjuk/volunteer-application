import SwiftUI

struct SearchEventsView: View {
    var body: some View {
        VStack(spacing: 0) {

            Divider()
                .padding(.top, 12)

            searchBar
                .padding(.horizontal, 14)
                .padding(.top, 22)

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .frame(height: 180)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "rectangle.grid.1x2")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(Color.gray.opacity(0.7))

                            Text("Здесь будет список возможностей")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.8))

                            Text("Пока экран без наполнения")
                                .font(.system(size: 14))
                                .foregroundStyle(.gray)
                        }
                    }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)

            Spacer()
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(red: 0.09, green: 0.60, blue: 0.93))

            Text("Search or start a new chat")
                .font(.system(size: 14))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray5))
        )
    }
}
