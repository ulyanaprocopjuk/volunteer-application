import SwiftUI

struct HomeSideMenuView: View {
    var onClose: () -> Void
    var onOpenProfile: () -> Void
    var onOpenMap: () -> Void
    var onOpenExplore: () -> Void
    var onOpenEvents: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            VStack(spacing: 10) {
                menuButton("Профиль", systemImage: "person.crop.circle", action: onOpenProfile)
                menuButton("Карта", systemImage: "globe.europe.africa", action: onOpenMap)
                menuButton("Поиск", systemImage: "magnifyingglass", action: onOpenExplore)
                menuButton("Мои события", systemImage: "calendar", action: onOpenEvents)
            }
            .padding(.top, 24)
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            Color.white
                .ignoresSafeArea()
        )
    }

    private var header: some View {
        HStack {
            Text("Menu")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.09, green: 0.60, blue: 0.93))

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(Color(.systemGray6))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
        .padding(.horizontal, 18)
    }

    private func menuButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(red: 0.09, green: 0.60, blue: 0.93))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}
