import SwiftUI

struct MapEventsView: View {
    var onMenuTap: () -> Void = {}
    var onNotificationsTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 18)
                .padding(.top, 14)

            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Color(red: 0.09, green: 0.60, blue: 0.93))

                Text("Maps")
                    .font(.system(size: 28, weight: .bold))

                Text("Здесь будет экран карты")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
            }

            Spacer()
        }
        .background(Color(.systemGray6).ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button {
                onMenuTap()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                onNotificationsTap()
            } label: {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }
}
