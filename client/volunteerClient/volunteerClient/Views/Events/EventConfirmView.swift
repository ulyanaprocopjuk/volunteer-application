import SwiftUI

struct EventConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EventViewModel
    let onConfirmed: ((EventResponse) -> Void)?

    @State private var createdAt = Date()
    @State private var showRatingPointsTooltip = false

    private let eventImageSize: CGFloat = 56

    var body: some View {
        ZStack {
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
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    confirmButton
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)
                }
            }
            .background(Color.white.ignoresSafeArea())

        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            createdAt = Date()
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("Подтверждение")
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

    @ViewBuilder
    private var eventPhotoView: some View {
        if let image = viewModel.eventPhotoImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: eventImageSize, height: eventImageSize)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Color(red: 18/255, green: 162/255, blue: 231/255).opacity(0.12))

                Image(systemName: "calendar")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
            }
            .frame(width: eventImageSize, height: eventImageSize)
        }
    }

    private var topBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            eventPhotoView

            Text(displayTitle)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.isVerifiedOrganization {
                ratingBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ratingBadge: some View {
        ZStack(alignment: .trailing) {
            if showRatingPointsTooltip {
                Text("+20% к рейтингу")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(red: 44/255, green: 67/255, blue: 102/255)))
                    .padding(.trailing, 34)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            }
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showRatingPointsTooltip.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 255/255, green: 214/255, blue: 0/255))
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
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

                HStack(spacing: 3) {
                    Text(displayOrganizer)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.black.opacity(0.62))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.isOrganizerVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
                    }
                }
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

    private var confirmButton: some View {
        Button {
            Task {
                await confirmEvent()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Подтвердить")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting || !viewModel.canSubmit)
        .opacity((viewModel.isSubmitting || !viewModel.canSubmit) ? 0.6 : 1)
    }

    private func confirmEvent() async {
        guard let response = await viewModel.submit(),
              viewModel.errorMessage == nil else { return }

        viewModel.clearSuccessMessage()

        if let onConfirmed {
            onConfirmed(response)
        } else {
            dismiss()
        }
    }

    private var displayTitle: String {
        let value = viewModel.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без названия" : value
    }

    private var displayDescription: String {
        viewModel.eventDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayDirection: String {
        viewModel.selectedDirection.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayLocation: String {
        let value = viewModel.locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Местоположение не указано" : value
    }

    private var displayDateRange: String {
        guard let startDate = viewModel.startDate else {
            return "Дата не указана"
        }

        return EventDateDisplayFormatter.dateRangeText(start: startDate, end: viewModel.endDate)
    }

    private var displayTimeRange: String {
        guard let startTime = viewModel.startTime else {
            return "Время не указано"
        }

        guard let startDate = viewModel.startDate else {
            return EventDateDisplayFormatter.timeText(startTime)
        }

        let startDateTime = viewModel.combine(day: startDate, time: startTime)
        let endDateTime: Date?
        if let endDate = viewModel.endDate,
           let endTime = viewModel.endTime,
           Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            endDateTime = viewModel.combine(day: endDate, time: endTime)
        } else {
            endDateTime = nil
        }

        return EventDateDisplayFormatter.timeRangeText(start: startDateTime, end: endDateTime)
    }

    private var displayVolunteersText: String {
        let count = Int(viewModel.volunteersManualInput) ?? viewModel.volunteersCount
        return "Требуется волонтёров: \(count)"
    }

    private var displayCreatedDate: String {
        Self.createdDateFormatter.string(from: createdAt)
    }

    private var displayOrganizer: String {
        let value = viewModel.organizerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Не указано" : value
    }

    private static let createdDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}

#Preview {
    let vm = EventViewModel(session: AppSession())
    vm.eventTitle = "Музыкальный фестиваль"
    vm.selectedDirection = EventDirectionOption.culture.rawValue
    vm.eventDescription = """
Помогите в организации фестиваля, координации гостей и работе площадок. Нам нужны активные и ответственные волонтёры, готовые поддержать мероприятие и создать комфортную атмосферу для всех участников.
"""
    vm.locationText = "ул. Аэродромная, Минск"
    vm.startDate = Date()
    vm.startTime = Date()
    vm.endDate = Date()
    vm.endTime = Calendar.current.date(byAdding: .hour, value: 4, to: Date())
    vm.volunteersManualInput = "3"

    return NavigationStack {
        EventConfirmView(viewModel: vm, onConfirmed: nil)
    }
}
