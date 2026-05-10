import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: EventViewModel

    @State private var isLocationSheetPresented = false
    @State private var isConfirmPresented = false
    @State private var activePicker: ActivePicker?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDirectionDropdown = false
    @State private var showRatingPointsPicker = false

    @State private var draftStartDate = Date()
    @State private var draftStartTime = Date()

    @State private var draftEndDate = Date()
    @State private var draftEndTime = Date()

    private let onBack: (() -> Void)?
    private let onEventSubmitted: ((EventResponse) -> Void)?

    enum ActivePicker: String, Identifiable {
        case start
        case end

        var id: String { rawValue }
    }

    init(
        session: AppSession,
        onBack: (() -> Void)? = nil,
        onEventSubmitted: ((EventResponse) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onEventSubmitted = onEventSubmitted
        _viewModel = StateObject(wrappedValue: EventViewModel(session: session))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            Rectangle()
                .fill(Color(.systemGray6))
                .frame(height: 108)
                .ignoresSafeArea(edges: .top)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 3)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 22) {
                        eventPhotoSection
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 2)

                        EventLabeledInputField(
                            title: "Название события",
                            text: $viewModel.eventTitle,
                            placeholder: "Введите название события"
                        )

                        EventDirectionDropdownField(
                            title: "Направление",
                            selectedValue: $viewModel.selectedDirection,
                            options: EventDirectionOption.allCases.map(\.rawValue),
                            placeholder: "Выберите направление",
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showDirectionDropdown = true
                                }
                            }
                        )

                        EventLabeledMultilineField(
                            title: "Описание",
                            text: $viewModel.eventDescription,
                            placeholder: "Введите описание события"
                        )

                        if viewModel.isVerifiedOrganization {
                            ratingPointsRow
                        }

                        EventPickerField(
                            title: "Местоположение",
                            value: viewModel.locationText,
                            placeholder: viewModel.locationPlaceholder,
                            error: viewModel.locationError,
                            systemImage: "mappin.and.ellipse"
                        ) {
                            isLocationSheetPresented = true
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            EventFieldTitle(title: "Начало события")

                            EventPickerField(
                                title: "",
                                value: viewModel.startDate != nil && viewModel.startTime != nil ? viewModel.formattedStartText : "",
                                placeholder: "Выберите начало события",
                                error: viewModel.startError,
                                systemImage: "calendar"
                            ) {
                                draftStartDate = viewModel.startDate ?? viewModel.defaultStartSelection()
                                draftStartTime = viewModel.startTime ?? viewModel.defaultStartSelection()
                                activePicker = .start
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            EventFieldTitle(title: "Конец события")

                            EventPickerField(
                                title: "",
                                value: viewModel.endDate != nil ? viewModel.formattedEndText : "",
                                placeholder: "Выберите конец события",
                                error: viewModel.endError,
                                systemImage: "calendar.badge.clock"
                            ) {
                                let defaultEnd = viewModel.defaultEndSelection()
                                draftEndDate = viewModel.endDate ?? defaultEnd
                                draftEndTime = viewModel.endTime ?? defaultEnd
                                activePicker = .end
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            EventFieldTitle(title: "Количество волонтёров")

                            HStack(spacing: 10) {
                                Button {
                                    viewModel.decreaseVolunteers()
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle().fill(Color(.systemGray5))
                                        )
                                }
                                .buttonStyle(.plain)

                                TextField("Количество", text: $viewModel.volunteersManualInput)
                                    .keyboardType(.phonePad)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 15))
                                    .onChange(of: viewModel.volunteersManualInput) { _, newValue in
                                        viewModel.updateVolunteersFromInput(newValue)
                                    }

                                Button {
                                    viewModel.increaseVolunteers()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle().fill(Color(.systemGray5))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 58)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        viewModel.volunteersError == nil
                                            ? Color.gray.opacity(0.45)
                                            : Color.red,
                                        lineWidth: 1
                                    )
                            )

                            if let error = viewModel.volunteersError {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    Button {
                        proceedToConfirmation()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                            if viewModel.isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Далее")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                    .opacity((!viewModel.canSubmit || viewModel.isSubmitting) ? 0.55 : 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                }
                .padding(.bottom, 18)
            }
        }
        .navigationTitle("Новое событие")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $isLocationSheetPresented) {
            if let context = viewModel.locationContext {
                EventLocationPickerSheet(
                    context: context,
                    initialSelection: viewModel.currentLocationSelection
                ) { selection in
                    viewModel.setLocation(selection)
                }
            } else {
                ProgressView("Загрузка...")
                    .presentationDetents([.height(180)])
            }
        }
        .sheet(item: $activePicker) { picker in
            EventDateTimePickerSheet(
                picker: picker,
                minimumDay: picker == .start
                    ? viewModel.todayStart
                    : max(viewModel.todayStart, viewModel.startDate ?? viewModel.todayStart),
                initialDay: picker == .start
                    ? draftStartDate
                    : draftEndDate,
                initialTime: picker == .start
                    ? draftStartTime
                    : draftEndTime,
                startDay: viewModel.startDate
            ) { day, time in
                switch picker {
                case .start:
                    draftStartDate = day
                    draftStartTime = time ?? draftStartTime
                    viewModel.startDate = viewModel.stripTime(from: day)
                    viewModel.startTime = time ?? draftStartTime

                    if let endDate = viewModel.endDate,
                       endDate < viewModel.stripTime(from: day) {
                        viewModel.endDate = viewModel.stripTime(from: day)
                    }

                    if let endDate = viewModel.endDate,
                       let endTime = viewModel.endTime {
                        let effectiveStartTime = time ?? draftStartTime
                        let startDateTime = viewModel.combine(
                            day: viewModel.stripTime(from: day),
                            time: effectiveStartTime
                        )
                        let endDateTime = viewModel.combine(day: endDate, time: endTime)

                        if endDateTime <= startDateTime {
                            let adjustedEnd = Calendar.current.date(
                                byAdding: .hour,
                                value: 1,
                                to: startDateTime
                            ) ?? startDateTime

                            viewModel.endDate = viewModel.stripTime(from: adjustedEnd)
                            viewModel.endTime = adjustedEnd
                            draftEndDate = adjustedEnd
                            draftEndTime = adjustedEnd
                        }
                    }

                case .end:
                    draftEndDate = day
                    if let time {
                        draftEndTime = time
                    }
                    viewModel.endDate = viewModel.stripTime(from: day)
                    if let startDate = viewModel.startDate,
                       !Calendar.current.isDate(startDate, inSameDayAs: viewModel.stripTime(from: day)) {
                        viewModel.endTime = nil
                    } else {
                        viewModel.endTime = time
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isConfirmPresented) {
            EventConfirmView(
                viewModel: viewModel,
                onConfirmed: { response in
                    handleEventSubmitted(response)
                }
            )
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadProfileContextIfNeeded()
        }
        .task(id: selectedPhotoItem) {
            await loadPhoto()
        }
        .overlayPreferenceValue(DirectionButtonAnchorKey.self) { anchor in
            if showDirectionDropdown, let anchor {
                GeometryReader { geo in
                    DirectionFloatingDropdown(
                        options: EventDirectionOption.allCases.map(\.rawValue),
                        selectedValue: $viewModel.selectedDirection,
                        frame: geo[anchor],
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.22)) {
                                showDirectionDropdown = false
                            }
                        }
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showDirectionDropdown)
        .sheet(isPresented: $showRatingPointsPicker) {
            RatingPointsPickerSheet(selectedPoints: $viewModel.ratingPoints)
        }
    }

    private var ratingPointsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            EventFieldTitle(title: "Очки за участие")

            Button {
                showRatingPointsPicker = true
            } label: {
                HStack {
                    Text("Укажите количество очков за участие в этом событии")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.62))
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Text("\(viewModel.ratingPoints)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
                        .frame(minWidth: 36)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 58)
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @MainActor
    private var eventPhotoSection: some View {
        let photoImage = viewModel.eventPhotoImage

        return PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack {
                if let image = photoImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(red: 231/255, green: 243/255, blue: 247/255))
                        .frame(width: 104, height: 104)

                    Image(systemName: "calendar")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(red: 42/255, green: 42/255, blue: 42/255))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func proceedToConfirmation() {
        viewModel.clearMessages()

        guard viewModel.canSubmit else {
            viewModel.errorMessage = "Заполните все обязательные поля"
            return
        }

        isConfirmPresented = true
    }

    private func handleBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private func handleEventSubmitted(_ event: EventResponse) {
        if let onEventSubmitted {
            onEventSubmitted(event)
        } else if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private func loadPhoto() async {
        guard let selectedPhotoItem else { return }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                viewModel.errorMessage = "Не удалось загрузить фото"
                return
            }

            viewModel.setEventPhoto(image)
        } catch {
            viewModel.errorMessage = "Не удалось открыть фото"
        }
    }
}

private struct EventLabeledInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EventFieldTitle(title: title)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(true)
                .font(.system(size: 15))
                .padding(.horizontal, 18)
                .frame(height: 58)
                .overlay(
                    Capsule()
                        .stroke(error == nil ? Color.gray.opacity(0.45) : Color.red, lineWidth: 1)
                )

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
    }
}

private struct EventLabeledMultilineField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EventFieldTitle(title: title)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                    .frame(height: 170)

                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.gray)
                        .font(.system(size: 15))
                        .padding(.top, 14)
                        .padding(.leading, 18)
                }

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(height: 170)
            }
        }
    }
}

private struct DirectionButtonAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct EventDirectionDropdownField: View {
    let title: String
    @Binding var selectedValue: String
    let options: [String]
    let placeholder: String
    let onTap: () -> Void

    private var trimmedValue: String {
        selectedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                EventFieldTitle(title: title)

                Spacer()

                Button { onTap() } label: {
                    HStack(spacing: 6) {
                        Text(trimmedValue.isEmpty ? "Выбрать" : "Изменить")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .anchorPreference(key: DirectionButtonAnchorKey.self, value: .bounds) { $0 }
            }

            if trimmedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            } else {
                Text(trimmedValue)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .padding(.leading, 8)
            }
        }
    }
}

private struct DirectionFloatingDropdown: View {
    let options: [String]
    @Binding var selectedValue: String
    let frame: CGRect
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selectedValue = option
                        onDismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(option)
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 12)

                            if selectedValue == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if option != options.last {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .frame(width: 260)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
            .offset(x: frame.maxX - 260, y: frame.maxY + 8)
        }
    }
}

private struct EventPickerField: View {
    let title: String
    let value: String
    let placeholder: String
    let error: String?
    let systemImage: String
    let action: () -> Void

    private var displayText: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? placeholder : trimmed
    }

    private var isPlaceholder: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: title.isEmpty ? 0 : 8) {
            if !title.isEmpty {
                EventFieldTitle(title: title)
            }

            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))

                    Text(displayText)
                        .font(.system(size: 15))
                        .foregroundColor(isPlaceholder ? .gray : .black)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 58)
                .frame(maxWidth: .infinity)
                .overlay(
                    Capsule()
                        .stroke(error == nil ? Color.gray.opacity(0.45) : Color.red, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
    }
}

private struct EventDateTimePickerSheet: View {
    enum Step {
        case day
        case time
    }

    @Environment(\.dismiss) private var dismiss

    let picker: EventFormView.ActivePicker
    let minimumDay: Date
    let startDay: Date?
    let onSave: (Date, Date?) -> Void

    @State private var step: Step = .day
    @State private var draftDay: Date
    @State private var draftTime: Date

    init(
        picker: EventFormView.ActivePicker,
        minimumDay: Date,
        initialDay: Date,
        initialTime: Date,
        startDay: Date? = nil,
        onSave: @escaping (Date, Date?) -> Void
    ) {
        self.picker = picker
        self.minimumDay = minimumDay
        self.startDay = startDay
        self.onSave = onSave
        _draftDay = State(initialValue: initialDay)
        _draftTime = State(initialValue: initialTime)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 16)

            Divider()

            Group {
                switch step {
                case .day:
                    DatePicker(
                        "",
                        selection: $draftDay,
                        in: dayRange,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)

                case .time:
                    DatePicker(
                        "",
                        selection: $draftTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                }
            }
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .frame(maxWidth: .infinity)
            .frame(height: 216)
            .clipped()

            if picker == .end && step == .time {
                Button {
                    onSave(draftDay, nil)
                    dismiss()
                } label: {
                    Text("Не указывать")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private var sheetHeight: CGFloat {
        if picker == .end && step == .time {
            return 350
        } else {
            return 280
        }
    }

    private var header: some View {
        HStack {
            Button(step == .day ? "Отменить" : "Назад") {
                if step == .day {
                    dismiss()
                } else {
                    step = .day
                }
            }
            .font(.system(size: 16))

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .semibold))

            Spacer()

            Button(step == .day ? "Далее" : "Готово") {
                handlePrimaryAction()
            }
            .font(.system(size: 16, weight: .semibold))
        }
    }

    private var title: String {
        switch (picker, step) {
        case (.start, .day):
            return "Выберите дату начала"
        case (.start, .time):
            return "Выберите время начала"
        case (.end, .day):
            return "Выберите дату окончания"
        case (.end, .time):
            return "Выберите время окончания"
        }
    }

    private var dayRange: ClosedRange<Date> {
        Calendar.current.startOfDay(for: minimumDay)...Date.distantFuture
    }

    private func handlePrimaryAction() {
        switch step {
        case .day:
            draftDay = Calendar.current.startOfDay(for: draftDay)
            if picker == .end,
               let startDay,
               !Calendar.current.isDate(startDay, inSameDayAs: draftDay) {
                onSave(draftDay, nil)
                dismiss()
                return
            }
            step = .time
        case .time:
            onSave(draftDay, draftTime)
            dismiss()
        }
    }
}

private struct EventFieldTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .regular, design: .serif))
            .padding(.leading, 8)
    }
}

private struct EventLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (EventLocationSelection) -> Void
    @FocusState private var isSearchFieldFocused: Bool

    @StateObject private var viewModel: EventLocationPickerViewModel
    @State private var zoomInTrigger = 0
    @State private var zoomOutTrigger = 0

    init(
        context: EventLocationContext,
        initialSelection: EventLocationSelection? = nil,
        onSelect: @escaping (EventLocationSelection) -> Void
    ) {
        self.onSelect = onSelect
        _viewModel = StateObject(
            wrappedValue: EventLocationPickerViewModel(
                context: context,
                initialSelection: initialSelection
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if !viewModel.suggestions.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.suggestions) { suggestion in
                                    Button {
                                        Task {
                                            await viewModel.chooseSuggestion(suggestion)
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(suggestion.title)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.gray)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)

                                    Divider()
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                        )
                        .padding(.horizontal, 16)
                    }

                    ZStack {
                        EventMapView(
                            cameraCoordinate: viewModel.cameraCoordinate,
                            zoomInTrigger: zoomInTrigger,
                            zoomOutTrigger: zoomOutTrigger
                        ) { coordinate in
                            Task {
                                await viewModel.handleMapTap(coordinate)
                            }
                        } onRegionDidChange: { coordinate in
                            viewModel.handleMapRegionDidChange(to: coordinate)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color(red: 44/255, green: 67/255, blue: 102/255))
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                            .offset(y: -14)
                            .allowsHitTesting(false)

                        VStack(spacing: 8) {
                            mapZoomButton(systemImage: "plus") {
                                zoomInTrigger += 1
                            }

                            mapZoomButton(systemImage: "minus") {
                                zoomOutTrigger += 1
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(12)

                        if viewModel.isSearching || viewModel.isInitialLocationLoading {
                            ProgressView()
                                .padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(height: 340)
                    .padding(.horizontal, 16)

                    if let feedbackMessage = viewModel.searchFeedbackMessage {
                        Text(feedbackMessage)
                            .font(.system(size: 13))
                            .foregroundColor(viewModel.searchFeedbackIsError ? .red : .gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Выбранная локация")
                            .font(.system(size: 16, weight: .semibold))

                        Text(viewModel.selectedLocation?.address ?? "Выберите местоположение")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 90)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button {
                    guard let selection = viewModel.selectedLocation else { return }
                    onSelect(selection)
                    dismiss()
                } label: {
                    Text("Выбрать эту локацию")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                        )
                }
                .disabled(viewModel.selectedLocation == nil)
                .opacity(viewModel.selectedLocation == nil ? 0.55 : 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.background)
            }
            .navigationTitle("Местоположение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                await viewModel.loadInitialLocationIfNeeded()
            }
        }
    }

    private func mapZoomButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black.opacity(0.78))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                )
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))

            TextField("Искать улицу, дом, здание, организацию", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 15))

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct RatingPointsPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPoints: Int

    private let options = Array(stride(from: 50, through: 100, by: 5))

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            Text("Очки за участие")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 16)

            Picker("", selection: $selectedPoints) {
                ForEach(options, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 160)
            .padding(.horizontal, 24)

            Button {
                dismiss()
            } label: {
                Text("Готово")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    NavigationStack {
        EventFormView(session: AppSession())
    }
}
