import SwiftUI

struct MapEventsView: View {
    var onCreateEventTap: () -> Void = {}
    var onNotificationsTap: () -> Void = {}
    var hasNotifications: Bool = false

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
                onCreateEventTap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                onNotificationsTap()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)

                    if hasNotifications {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: -6, y: 6)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
