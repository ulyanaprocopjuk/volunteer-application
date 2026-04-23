import SwiftUI
import MapKit
import CoreLocation

struct EventFormView: View {
    @StateObject private var viewModel = EventViewModel()

    @State private var isLocationSheetPresented = false
    @State private var activePicker: ActivePicker?

    @State private var draftStartDate = Date()
    @State private var draftStartTime = Date()

    @State private var draftEndDate = Date()
    @State private var draftEndTime = Date()

    enum ActivePicker: String, Identifiable {
        case start
        case end

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 22) {
                    EventLabeledInputField(
                        title: "Название события",
                        text: $viewModel.eventTitle,
                        placeholder: "Введите название события"
                    )

                    EventLabeledMultilineField(
                        title: "Описание",
                        text: $viewModel.eventDescription,
                        placeholder: "Введите описание события"
                    )

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
                                .onChange(of: viewModel.volunteersManualInput) { newValue in
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
                    Task {
                        await viewModel.submit()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                        if viewModel.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Создать событие")
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
        .background(Color(.systemGray6).ignoresSafeArea())
        .navigationTitle("Новое событие")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isLocationSheetPresented) {
            EventLocationPickerSheet(viewModel: viewModel)
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
                    : draftEndTime
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
                    viewModel.endTime = time
                }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Готово", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { _ in viewModel.successMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.successMessage ?? "")
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
    let onSave: (Date, Date?) -> Void

    @State private var step: Step = .day
    @State private var draftDay: Date
    @State private var draftTime: Date

    init(
        picker: EventFormView.ActivePicker,
        minimumDay: Date,
        initialDay: Date,
        initialTime: Date,
        onSave: @escaping (Date, Date?) -> Void
    ) {
        self.picker = picker
        self.minimumDay = minimumDay
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

    @ObservedObject var viewModel: EventViewModel
    @StateObject private var searchService = EventLocationSearchService()

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 53.9006, longitude: 27.5590),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    @State private var draftCoordinate: CLLocationCoordinate2D?
    @State private var draftLocationText = "Выберите местоположение"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if !searchService.suggestions.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(searchService.suggestions) { suggestion in
                                Button {
                                    Task {
                                        await selectSuggestion(suggestion)
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

                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        if let draftCoordinate {
                            Marker("Событие", coordinate: draftCoordinate)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture { point in
                        if let coordinate = proxy.convert(point, from: .local) {
                            draftCoordinate = coordinate
                            Task {
                                await resolveAddress(for: coordinate)
                            }
                        }
                    }
                }
                .frame(height: 340)
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Выбранная локация")
                        .font(.system(size: 16, weight: .semibold))

                    Text(draftLocationText)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                Button {
                    guard let draftCoordinate else { return }
                    viewModel.setLocation(title: draftLocationText, coordinate: draftCoordinate)
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
                .disabled(draftCoordinate == nil)
                .opacity(draftCoordinate == nil ? 0.55 : 1)
                .padding(.horizontal, 16)

                Spacer()
            }
            .navigationTitle("Местоположение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                draftCoordinate = viewModel.selectedCoordinate

                if let selectedCoordinate = viewModel.selectedCoordinate {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: selectedCoordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    )
                }

                if !viewModel.locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draftLocationText = viewModel.locationText
                } else {
                    draftLocationText = "Выберите местоположение"
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))

            TextField("Искать адрес, улицу, дом, организацию", text: $searchService.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 15))
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

    private func selectSuggestion(_ suggestion: EventLocationSearchService.Suggestion) async {
        do {
            if let item = try await searchService.search(for: suggestion),
               let coordinate = item.placemark.location?.coordinate {
                draftCoordinate = coordinate
                draftLocationText = formattedPlacemark(
                    item.placemark,
                    fallbackTitle: suggestion.title,
                    fallbackSubtitle: suggestion.subtitle
                )

                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )

                searchService.query = draftLocationText
                searchService.suggestions = []
            }
        } catch {
            // no-op
        }
    }

    private func resolveAddress(for coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                draftLocationText = formattedPlacemark(
                    placemark,
                    fallbackTitle: "Выбранная точка",
                    fallbackSubtitle: ""
                )
            } else {
                draftLocationText = "Выберите местоположение"
            }
        } catch {
            draftLocationText = "Выберите местоположение"
        }
    }

    private func formattedPlacemark(
        _ placemark: CLPlacemark,
        fallbackTitle: String,
        fallbackSubtitle: String
    ) -> String {
        let street = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: ", ")

        let locality = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts: [String] = [
            street.nilIfEmpty,
            locality.nilIfEmpty
        ]
        .compactMap { $0 }

        if !parts.isEmpty {
            return parts.joined(separator: ", ")
        }

        let fallbackParts: [String] = [
            fallbackTitle.nilIfEmpty,
            fallbackSubtitle.nilIfEmpty
        ]
        .compactMap { $0 }

        return fallbackParts.isEmpty
            ? "Выберите местоположение"
            : fallbackParts.joined(separator: ", ")
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case .some(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .none:
            return nil
        }
    }
}

#Preview {
    NavigationStack {
        EventFormView()
    }
}
