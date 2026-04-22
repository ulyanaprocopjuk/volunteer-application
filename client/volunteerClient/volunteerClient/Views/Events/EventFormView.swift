import SwiftUI
import MapKit
import CoreLocation

struct EventFormView: View {
    @StateObject private var viewModel = EventFormViewModel()
    @State private var activeSheet: ActiveSheet?
    @State private var showCreatedAlert = false
    @State private var createdMessage = ""

    var onCreate: ((EventDraft) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    StyledTextFieldSection(
                        title: "Название события",
                        placeholder: "Введите название события",
                        text: $viewModel.title
                    )

                    StyledTextEditorSection(
                        title: "Описание",
                        placeholder: "Введите описание события",
                        text: $viewModel.descriptionText,
                        minHeight: 170
                    )

                    Button {
                        activeSheet = .location
                    } label: {
                        StyledSummaryField(
                            title: "Местоположение",
                            value: viewModel.locationDisplayText,
                            placeholder: "Выберите местоположение"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeSheet = .start
                    } label: {
                        StyledSummaryField(
                            title: "Начало события",
                            value: viewModel.formattedStart,
                            placeholder: "Выберите дату и время начала"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        activeSheet = .end
                    } label: {
                        StyledSummaryField(
                            title: "Конец события",
                            value: viewModel.formattedEnd,
                            placeholder: "Выберите дату и время окончания"
                        )
                    }
                    .buttonStyle(.plain)

                    VolunteerInputSection(
                        title: "Количество волонтёров",
                        text: $viewModel.volunteersInput,
                        error: viewModel.volunteersError,
                        onMinus: viewModel.decrementVolunteers,
                        onPlus: viewModel.incrementVolunteers,
                        onTextChanged: viewModel.updateVolunteersInput
                    )

                    Button {
                        guard let draft = viewModel.buildDraft() else { return }
                        onCreate?(draft)

                        createdMessage = """
                        Событие создано.
                        \(draft.title)
                        \(DateFormatters.dateTime.string(from: draft.startAt))
                        """
                        showCreatedAlert = true
                    } label: {
                        Text("Создать событие")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(viewModel.isValid ? Color(red: 44/255, green: 67/255, blue: 102/255) : Color.gray.opacity(0.45))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isValid)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGray6))
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .location:
                LocationPickerView(
                    initialLocation: viewModel.selectedLocation
                ) { location in
                    viewModel.setLocation(location)
                }

            case .start:
                EventDateTimePickerSheet(
                    mode: .start,
                    minimumDay: viewModel.todayStart,
                    initialDay: viewModel.startDay ?? viewModel.defaultStartDate(),
                    initialTime: viewModel.startTime ?? viewModel.defaultStartTime()
                ) { day, time in
                    guard let time else { return }
                    viewModel.saveStart(day: day, time: time)
                }

            case .end:
                EventDateTimePickerSheet(
                    mode: .end,
                    minimumDay: max(viewModel.todayStart, viewModel.startDay ?? viewModel.todayStart),
                    initialDay: viewModel.endDay ?? (viewModel.startDay ?? viewModel.defaultEndDate()),
                    initialTime: viewModel.endTime ?? viewModel.defaultEndTime()
                ) { day, time in
                    viewModel.saveEnd(day: day, time: time)
                }
            }
        }
        .alert("Готово", isPresented: $showCreatedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(createdMessage)
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)

            Text("Создание события")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.black)
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private enum ActiveSheet: String, Identifiable {
    case location
    case start
    case end

    var id: String { rawValue }
}

struct EventDateTimePickerSheet: View {
    enum Mode {
        case start
        case end

        var title: String {
            switch self {
            case .start: return "Начало события"
            case .end: return "Конец события"
            }
        }

        var dateTitle: String {
            switch self {
            case .start: return "Выберите дату начала"
            case .end: return "Выберите дату окончания"
            }
        }

        var timeTitle: String {
            switch self {
            case .start: return "Выберите время начала"
            case .end: return "Выберите время окончания"
            }
        }
    }

    private enum Step {
        case day
        case time
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let minimumDay: Date
    let onSave: (Date, Date?) -> Void

    @State private var step: Step = .day
    @State private var draftDay: Date
    @State private var draftTime: Date

    init(
        mode: Mode,
        minimumDay: Date,
        initialDay: Date,
        initialTime: Date,
        onSave: @escaping (Date, Date?) -> Void
    ) {
        self.mode = mode
        self.minimumDay = minimumDay
        self.onSave = onSave
        _draftDay = State(initialValue: initialDay)
        _draftTime = State(initialValue: initialTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if step == .day {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(mode.dateTitle)
                            .font(.system(size: 18, weight: .semibold))

                        DatePicker(
                            "",
                            selection: $draftDay,
                            in: minimumDay...Date.distantFuture,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 180)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(mode.timeTitle)
                            .font(.system(size: 18, weight: .semibold))

                        DatePicker(
                            "",
                            selection: $draftTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 180)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step == .day {
                        Button("Отмена") {
                            dismiss()
                        }
                    } else {
                        if mode == .end {
                            Button("Отменить") {
                                onSave(draftDay, nil)
                                dismiss()
                            }
                        } else {
                            Button("Назад") {
                                step = .day
                            }
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(step == .day ? "Готово" : "Сохранить") {
                        if step == .day {
                            step = .time
                        } else {
                            onSave(draftDay, draftTime)
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}


struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Поиск адреса, улицы, дома, организации", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct SearchCompletionRow: View {
    let completion: MKLocalSearchCompletion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(completion.title)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct StyledTextFieldSection: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(.primary)

            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.secondary))
                .font(.system(size: 15))
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
        }
    }
}

struct StyledTextEditorSection: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(.primary)

            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15))
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: minHeight)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

struct StyledSummaryField: View {
    let title: String
    let value: String
    let placeholder: String

    private var displayValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholder : value
    }

    private var isPlaceholder: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(.primary)

            HStack {
                Text(displayValue)
                    .font(.system(size: 15))
                    .foregroundStyle(isPlaceholder ? .secondary : .primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

struct VolunteerInputSection: View {
    let title: String
    @Binding var text: String
    let error: String?
    let onMinus: () -> Void
    let onPlus: () -> Void
    let onTextChanged: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(.primary)

            HStack(spacing: 10) {
                Button(action: onMinus) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(Color(.secondarySystemGroupedBackground))
                        )
                }
                .buttonStyle(.plain)

                TextField("Количество", text: $text)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15))
                    .onChange(of: text) { newValue in
                        onTextChanged(newValue)
                    }

                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(Color(.secondarySystemGroupedBackground))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(error == nil ? Color.gray.opacity(0.25) : Color.red, lineWidth: 1)
            )

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .padding(.leading, 8)
            }
        }
    }
}

#Preview {
    EventFormView { draft in
        print(draft.title)
    }
}
