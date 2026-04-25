import SwiftUI

struct EventConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EventViewModel
    let onConfirmed: ((EventResponse) -> Void)?

    @State private var createdAt = Date()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        eventCard
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 24)
                    }
                }

                confirmButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .background(Color(.systemGray6))
            }
            .background(Color(.systemGray6).ignoresSafeArea())

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

            Text("Подтверждение")
                .font(.system(size: 22, weight: .semibold, design: .serif))
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
        .frame(height: 74)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var eventCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBlock

            if !displayDescription.isEmpty {
                Text(displayDescription)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundColor(.black.opacity(0.62))
                    .lineSpacing(8)
                    .padding(.top, 26)
            }

            infoBlock
                .padding(.top, 42)

            bottomMetaBlock
                .padding(.top, 36)
        }
    }

    private var topBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(displayTitle)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var infoBlock: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
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

            Spacer(minLength: 16)
        }
    }

    private var bottomMetaBlock: some View {
        HStack(alignment: .center) {
            Text(displayVolunteersText)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(Color(red: 58/255, green: 145/255, blue: 233/255))

            Spacer()

            Text(displayCreatedDate)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.55))
        }
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

    private var displayLocation: String {
        let value = viewModel.locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Местоположение не указано" : value
    }

    private var displayDateRange: String {
        guard let startDate = viewModel.startDate else {
            return "Дата не указана"
        }

        let startText = Self.shortDateFormatter.string(from: startDate)

        if let endDate = viewModel.endDate {
            let endText = Self.shortDateFormatter.string(from: endDate)
            return "\(startText) — \(endText)"
        } else {
            return "\(startText)"
        }
    }

    private var displayTimeRange: String {
        guard let startTime = viewModel.startTime else {
            return "Время не указано"
        }

        let startText = Self.timeFormatter.string(from: startTime)

        if let endTime = viewModel.endTime {
            let endText = Self.timeFormatter.string(from: endTime)

            return "\(startText) — \(endText)"
        } else {
            return "\(startText)"
        }
    }

    private var displayVolunteersText: String {
        let count = Int(viewModel.volunteersManualInput) ?? viewModel.volunteersCount
        return "Требуется волонтёров: \(count)"
    }

    private var displayCreatedDate: String {
        "Создано \(Self.createdDateFormatter.string(from: createdAt))"
    }

    private static let shortDateFormatter: DateFormatter = {
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
