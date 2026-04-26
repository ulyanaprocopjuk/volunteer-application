import SwiftUI

struct EventSummaryCard: View {
    let event: EventResponse
    var showFullDescription: Bool = false

    private var moderationStatus: EventModerationStatus {
        EventModerationStatus(rawValue: event.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                eventThumbnail

                VStack(alignment: .leading, spacing: 10) {
                    Text(event.title)
                        .font(.system(size: 23, weight: .bold, design: .serif))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text("Статус:")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundColor(.black.opacity(0.7))

                        Text(statusText)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundColor(statusColor)
                    }
                }
            }

            if !event.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(event.description)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.62))
                    .lineSpacing(7)
                    .lineLimit(showFullDescription ? nil : 3)
                    .padding(.top, 20)
            }

            VStack(alignment: .leading, spacing: 14) {
                infoRow(icon: "mappin.and.ellipse", text: locationText)
                infoRow(icon: "calendar", text: dateRangeText)
                infoRow(icon: "clock", text: timeRangeText)
            }
            .padding(.top, 28)

            HStack(alignment: .top) {
                Text("Требуется волонтёров: \(event.volunteersNeeded)")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(Color(red: 58/255, green: 145/255, blue: 233/255))

                Spacer(minLength: 16)

                Text(createdAtText)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(.black.opacity(0.55))
            }
            .padding(.top, 30)

            Rectangle()
                .fill(Color(red: 58/255, green: 145/255, blue: 233/255))
                .frame(height: 2)
                .padding(.top, 18)
        }
        .padding(20)
        .background(Color(.systemGray6))
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }

    private var eventThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)

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
                        placeholderThumbnail
                    @unknown default:
                        placeholderThumbnail
                    }
                }
            } else {
                placeholderThumbnail
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
    }

    private var placeholderThumbnail: some View {
        Image(systemName: "calendar")
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
    }

    private var statusText: String {
        switch moderationStatus {
        case .pending:
            return "Ожидает подтверждения"
        case .approved:
            return "Подтверждено"
        case .rejected:
            return "Отклонено"
        }
    }

    private var statusColor: Color {
        switch moderationStatus {
        case .pending:
            return Color(red: 0.82, green: 0.62, blue: 0.07)
        case .approved:
            return Color(red: 0.16, green: 0.56, blue: 0.23)
        case .rejected:
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        }
    }

    private var locationText: String {
        let cityCountry = "\(event.city), \(event.country)"
        let location = event.locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if location.isEmpty {
            return cityCountry
        }

        return location
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

    private var dateRangeText: String {
        let startText = Self.dateFormatter.string(from: startDate)

        if let endDate {
            return "\(startText) - \(Self.dateFormatter.string(from: endDate))"
        }

        return startText
    }

    private var timeRangeText: String {
        let startText = Self.timeFormatter.string(from: startDate)

        if let endDate {
            return "\(startText) - \(Self.timeFormatter.string(from: endDate))"
        }

        return startText
    }

    private var createdAtText: String {
        let date = createdDate ?? startDate
        return Self.createdAtFormatter.string(from: date)
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let createdAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()
}
