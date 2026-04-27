import SwiftUI

struct EventDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let event: EventResponse

    private let eventImageSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    eventCard
                        .padding(.horizontal, 24)
                        .padding(.top, 25)
                        .padding(.bottom, 24)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("Детали события")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.78))

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                .background(Circle().fill(Color.clear))
                        )
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBlock

            if !displayDirection.isEmpty {
                directionRow
                    .padding(.top, 18)
            }

            if !displayDescription.isEmpty {
                Text(displayDescription)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.62))
                    .lineSpacing(8)
                    .padding(.top, displayDirection.isEmpty ? 26 : 18)
            }

            infoBlock
                .padding(.top, 30)

            bottomMetaBlock
                .padding(.top, 28)
        }
    }

    private var eventPhotoView: some View {
        ZStack {
            Circle()
                .fill(Color(red: 18/255, green: 162/255, blue: 231/255).opacity(0.12))

            if let photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        placeholderPhoto
                    @unknown default:
                        placeholderPhoto
                    }
                }
            } else {
                placeholderPhoto
            }
        }
        .frame(width: eventImageSize, height: eventImageSize)
        .clipShape(Circle())
    }

    private var placeholderPhoto: some View {
        Image(systemName: "calendar")
            .font(.system(size: 26, weight: .semibold))
            .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
    }

    private var topBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            eventPhotoView

            Text(displayTitle)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoRow(
                icon: "mappin.and.ellipse",
                text: displayLocation
            )

            infoRow(
                icon: "calendar",
                text: displayDateRange
            )

            infoRow(
                icon: "clock",
                text: displayTimeRange
            )
        }
    }

    private var bottomMetaBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Text(displayVolunteersText)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(Color(red: 58/255, green: 145/255, blue: 233/255))

                Text("Дата создания: \(displayCreatedDate)")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.55))
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Организатор:")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.48))

                Text(displayOrganizer)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.62))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 90, alignment: .leading)
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    private var directionRow: some View {
        HStack(spacing: 8) {
            Text("Направление:")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            Text(displayDirection)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var displayTitle: String {
        let value = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без названия" : value
    }

    private var displayDescription: String {
        event.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayDirection: String {
        event.direction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var displayLocation: String {
        let location = event.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !location.isEmpty {
            return location
        }

        return "\(event.country), \(event.city)"
    }

    private var displayDateRange: String {
        EventDateDisplayFormatter.dateRangeText(start: startDate, end: endDate)
    }

    private var displayTimeRange: String {
        EventDateDisplayFormatter.timeRangeText(start: startDate, end: endDate)
    }

    private var displayVolunteersText: String {
        "Требуется волонтёров: \(event.volunteersNeeded)"
    }

    private var displayCreatedDate: String {
        let date = createdDate ?? startDate
        return Self.createdDateFormatter.string(from: date)
    }

    private var displayOrganizer: String {
        let value = event.organizerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "Не указано" : value
    }

    private var photoURL: URL? {
        guard let photoURL = event.photoURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !photoURL.isEmpty else {
            return nil
        }

        if let url = URL(string: photoURL), url.scheme != nil {
            return url
        }

        guard let baseURL = URL(string: AppConfig.baseURLString) else {
            return nil
        }

        let path = photoURL.hasPrefix("/") ? String(photoURL.dropFirst()) : photoURL
        return baseURL.appendingPathComponent(path)
    }

    private var startDate: Date {
        Self.isoFormatter.date(from: event.startsAt) ?? Date()
    }

    private var endDate: Date? {
        guard let value = event.endsAt else { return nil }
        return Self.isoFormatter.date(from: value)
    }

    private var createdDate: Date? {
        guard let value = event.createdAt else { return nil }
        return Self.isoFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let createdDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

#Preview {
    EventDetailsView(
        event: EventResponse(
            id: "1",
            title: "Музыкальный фестиваль",
            direction: EventDirectionOption.culture.rawValue,
            description: "Описание события",
            country: "Беларусь",
            city: "Минск",
            locationName: "ул. Аэродромная, Минск",
            photoURL: nil,
            latitude: 53.9,
            longitude: 27.56,
            startsAt: "2026-04-24T10:00:00Z",
            endsAt: "2026-04-24T14:00:00Z",
            volunteersNeeded: 3,
            status: "pending",
            message: nil,
            organizerName: "Анна Иванова",
            createdAt: "2026-04-24T09:00:00Z"
        )
    )
}
