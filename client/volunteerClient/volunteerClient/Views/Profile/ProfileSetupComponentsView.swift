import SwiftUI

struct LabeledInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .padding(.leading, 8)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(true)
                .font(.system(size: 15))
                .padding(.horizontal, 18)
                .frame(height: 58)
                .overlay(
                    Capsule()
                        .stroke(error == nil ? Color.gray.opacity(0.5) : Color.red, lineWidth: 1)
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

struct LabeledPhoneField: View {
    let title: String
    @Binding var localNumber: String
    let selectedCountry: ProfileSetupViewModel.PhoneCountry
    let countries: [ProfileSetupViewModel.PhoneCountry]
    let error: String?
    let onSelectCountry: (ProfileSetupViewModel.PhoneCountry) -> Void

    @State private var isCountryPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .padding(.leading, 8)

            HStack(spacing: 10) {
                Button {
                    isCountryPickerPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedCountry.flag)
                            .font(.system(size: 18))

                        Text(selectedCountry.code)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .frame(minWidth: 94, alignment: .leading)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 1, height: 28)

                TextField(selectedCountry.placeholder, text: $localNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .onChange(of: localNumber) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        let maxLen = selectedCountry.localNumberLength
                        if digits.count > maxLen {
                            localNumber = String(digits.prefix(maxLen))
                        } else if digits != newValue {
                            localNumber = digits
                        }
                    }
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .overlay(
                Capsule()
                    .stroke(error == nil ? Color.gray.opacity(0.5) : Color.red, lineWidth: 1)
            )

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
        .sheet(isPresented: $isCountryPickerPresented) {
            PhoneCountrySelectionSheet(
                countries: countries,
                selectedCountry: selectedCountry
            ) { country in
                onSelectCountry(country)
                isCountryPickerPresented = false
            }
        }
    }
}

struct PhoneCountrySelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let countries: [ProfileSetupViewModel.PhoneCountry]
    let selectedCountry: ProfileSetupViewModel.PhoneCountry
    let onSelect: (ProfileSetupViewModel.PhoneCountry) -> Void

    var body: some View {
        NavigationStack {
            List(countries) { country in
                Button {
                    onSelect(country)
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag)
                            .font(.system(size: 22))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(country.name)
                                .foregroundColor(.black)

                            Text(country.code)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if country == selectedCountry {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Код страны")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

import SwiftUI

struct LabeledLocationField: View {
    let title: String
    @Binding var country: String
    @Binding var city: String
    let countries: [CityCountry]
    let error: String?
    let onSelectCountry: (String) -> Void

    @State private var isLocationSheetPresented = false

    private var displayText: String {
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedCountry.isEmpty && !trimmedCity.isEmpty {
            return "\(trimmedCountry), \(trimmedCity)"
        } else {
            return "Выберите страну и город"
        }
    }

    private var isPlaceholder: Bool {
        city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var countryBinding: Binding<String> {
        Binding(
            get: { country },
            set: { newValue in
                onSelectCountry(newValue)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .padding(.leading, 8)

            Button {
                isLocationSheetPresented = true
            } label: {
                HStack(spacing: 12) {
                    Text(displayText)
                        .font(.system(size: 15))
                        .foregroundColor(isPlaceholder ? .gray : .black)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 18)
                .frame(height: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(
                Capsule()
                    .stroke(error == nil ? Color.gray.opacity(0.5) : Color.red, lineWidth: 1)
            )

            if let error {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
        .sheet(isPresented: $isLocationSheetPresented) {
            LocationSelectionSheet(
                country: countryBinding,
                city: $city,
                countries: countries
            )
        }
    }
}

struct LocationSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var country: String
    @Binding var city: String
    let countries: [CityCountry]

    @State private var searchText = ""

    private var currentCountryCities: [String] {
        countries.first(where: { $0.country == country })?.cities ?? []
    }

    private var filteredCities: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return currentCountryCities
        }

        return currentCountryCities.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Menu {
                    ForEach(countries) { item in
                        Button(item.country) {
                            guard country != item.country else { return }
                            country = item.country
                            city = ""
                            searchText = ""
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(country)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Найти город", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .padding(.horizontal, 16)

                if filteredCities.isEmpty {
                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)

                        Text("Город не найден")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)

                        Text("Попробуйте изменить запрос")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                } else {
                    List(filteredCities, id: \.self) { item in
                        Button {
                            city = item
                            dismiss()
                        } label: {
                            HStack {
                                Text(item)
                                    .foregroundColor(.black)

                                Spacer()

                                if item == city {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding(.top, 8)
            .navigationTitle("Местонахождение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}


struct LabeledMultilineField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .padding(.leading, 8)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(height: 128)

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
                    .frame(height: 128)
            }
        }
    }
}

struct LabeledMultiSelectField: View {
    let title: String
    @Binding var selectedValues: Set<String>
    let options: [String]
    let placeholder: String

    @State private var isPresented = false

    private var orderedSelectedValues: [String] {
        options.filter { selectedValues.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .padding(.leading, 8)

                Spacer()

                Button {
                    isPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text(orderedSelectedValues.isEmpty ? "Выбрать" : "Изменить")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
            }

            if orderedSelectedValues.isEmpty {
                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
            } else {
                ChipFlowLayout(spacing: 10) {
                    ForEach(orderedSelectedValues, id: \.self) { skill in
                        SkillChip(title: skill)
                    }
                }
            }
        }
        .sheet(isPresented: $isPresented) {
            SkillSelectionSheet(
                title: title,
                selectedValues: $selectedValues,
                options: options
            )
        }
    }
}

struct SkillChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(Color(red: 62/255, green: 81/255, blue: 115/255))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 232/255, green: 235/255, blue: 240/255))
            .clipShape(Capsule())
    }
}

struct SkillSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    @Binding var selectedValues: Set<String>
    let options: [String]

    var body: some View {
        NavigationStack {
            List(options, id: \.self) { option in
                Button {
                    if selectedValues.contains(option) {
                        selectedValues.remove(option)
                    } else {
                        selectedValues.insert(option)
                    }
                } label: {
                    HStack {
                        Text(option)
                            .foregroundColor(.black)
                        Spacer()
                        if selectedValues.contains(option) {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 44/255, green: 67/255, blue: 102/255))
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
