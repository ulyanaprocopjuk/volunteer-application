import SwiftUI
import UIKit
import Combine

@MainActor
final class ProfileSetupViewModel: ObservableObject {
    enum ProfileType: String, CaseIterable {
        case volunteer = "Волонтёр"
        case organization = "Организация"

        var apiValue: String {
            switch self {
            case .volunteer: return "volunteer"
            case .organization: return "organization"
            }
        }
    }

    struct PhoneCountry: Identifiable, Equatable {
        let name: String
        let code: String
        let flag: String
        let placeholder: String
        let localNumberLength: Int

        var id: String {
            "\(name)-\(code)"
        }

        static let cisCountries: [PhoneCountry] = [
            PhoneCountry(name: "Беларусь", code: "+375", flag: "🇧🇾", placeholder: "291234567", localNumberLength: 9),
            PhoneCountry(name: "Россия", code: "+7", flag: "🇷🇺", placeholder: "9123456789", localNumberLength: 10),
            PhoneCountry(name: "Казахстан", code: "+7", flag: "🇰🇿", placeholder: "7012345678", localNumberLength: 10),
            PhoneCountry(name: "Армения", code: "+374", flag: "🇦🇲", placeholder: "77123456", localNumberLength: 8),
            PhoneCountry(name: "Азербайджан", code: "+994", flag: "🇦🇿", placeholder: "501234567", localNumberLength: 9),
            PhoneCountry(name: "Кыргызстан", code: "+996", flag: "🇰🇬", placeholder: "700123456", localNumberLength: 9),
            PhoneCountry(name: "Молдова", code: "+373", flag: "🇲🇩", placeholder: "60123456", localNumberLength: 8),
            PhoneCountry(name: "Таджикистан", code: "+992", flag: "🇹🇯", placeholder: "901234567", localNumberLength: 9),
            PhoneCountry(name: "Туркменистан", code: "+993", flag: "🇹🇲", placeholder: "61234567", localNumberLength: 8),
            PhoneCountry(name: "Узбекистан", code: "+998", flag: "🇺🇿", placeholder: "901234567", localNumberLength: 9)
        ]
    }

    @Published var selectedType: ProfileType = .volunteer
    @Published var avatarImage: UIImage?
    @Published var avatarURL: String?
    private var avatarData: Data?

    @Published var firstName = ""
    @Published var lastName = ""
    @Published var volunteerPhone = ""
    @Published var selectedVolunteerPhoneCountry = PhoneCountry.cisCountries[0]
    @Published var volunteerEmail = ""
    @Published var volunteerLocation = ""
    @Published var selectedSkills: Set<String> = []
    @Published var aboutMe = ""

    @Published var organizationName = ""
    @Published var organizationPhone = ""
    @Published var selectedOrganizationPhoneCountry = PhoneCountry.cisCountries[0]
    @Published var organizationEmail = ""
    @Published var organizationLocation = ""
    @Published var aboutOrganization = ""

    @Published var isLoading = false
    @Published var isProfileLoading = false
    @Published var errorMessage: String?
    @Published var profileLoadError: String?

    let skills = [
        "Общение с людьми",
        "Работа в команде",
        "Организация мероприятий",
        "Первая помощь",
        "Ответственность",
        "Стрессоустойчивость",
        "Лидерство",
        "Фото и видео",
        "Ведение соцсетей",
        "Дизайн",
        "Написание текстов",
        "Перевод",
        "Логистика",
        "Работа с документами",
        "Сбор помощи"
    ]

    private let api: ProfileAPIProtocol
    private unowned let session: AppSession
    private var hasLoadedProfile = false

    init(
        session: AppSession,
        api: ProfileAPIProtocol? = nil
    ) {
        self.session = session
        self.api = api ?? ProfileAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

    var isVolunteer: Bool {
        selectedType == .volunteer
    }

    var phoneCountries: [PhoneCountry] {
        PhoneCountry.cisCountries
    }

    var volunteerLocalPhoneNumber: String {
        localDigits(from: volunteerPhone, fallbackCountry: selectedVolunteerPhoneCountry)
    }

    var organizationLocalPhoneNumber: String {
        localDigits(from: organizationPhone, fallbackCountry: selectedOrganizationPhoneCountry)
    }

    var volunteerEmailError: String? {
        validateEmail(volunteerEmail)
    }

    var organizationEmailError: String? {
        validateEmail(organizationEmail)
    }

    var volunteerPhoneError: String? {
        validatePhone(volunteerPhone, country: selectedVolunteerPhoneCountry)
    }

    var organizationPhoneError: String? {
        validatePhone(organizationPhone, country: selectedOrganizationPhoneCountry)
    }

    var volunteerLocationError: String? {
        validateLocation(volunteerLocation)
    }

    var organizationLocationError: String? {
        validateLocation(organizationLocation)
    }

    var canSubmit: Bool {
        if isVolunteer {
            return !trim(firstName).isEmpty &&
                !trim(lastName).isEmpty &&
                !trim(volunteerPhone).isEmpty &&
                !trim(volunteerEmail).isEmpty &&
                !trim(volunteerLocation).isEmpty &&
                volunteerPhoneError == nil &&
                volunteerEmailError == nil &&
                volunteerLocationError == nil
        } else {
            return !trim(organizationName).isEmpty &&
                !trim(organizationPhone).isEmpty &&
                !trim(organizationEmail).isEmpty &&
                !trim(organizationLocation).isEmpty &&
                organizationPhoneError == nil &&
                organizationEmailError == nil &&
                organizationLocationError == nil
        }
    }

    func setAvatar(_ image: UIImage) {
        avatarImage = image
        avatarURL = nil
        avatarData = image.jpegData(compressionQuality: 0.82)
    }

    func setVolunteerLocalPhoneNumber(_ value: String) {
        volunteerPhone = phoneValue(
            fromLocalInput: value,
            country: selectedVolunteerPhoneCountry,
            currentPhone: volunteerPhone
        )
    }

    func setOrganizationLocalPhoneNumber(_ value: String) {
        organizationPhone = phoneValue(
            fromLocalInput: value,
            country: selectedOrganizationPhoneCountry,
            currentPhone: organizationPhone
        )
    }

    func selectVolunteerPhoneCountry(_ country: PhoneCountry) {
        volunteerPhone = phoneValueAfterCountryChange(
            to: country,
            currentPhone: volunteerPhone,
            currentCountry: selectedVolunteerPhoneCountry
        )
        selectedVolunteerPhoneCountry = country
    }

    func selectOrganizationPhoneCountry(_ country: PhoneCountry) {
        organizationPhone = phoneValueAfterCountryChange(
            to: country,
            currentPhone: organizationPhone,
            currentCountry: selectedOrganizationPhoneCountry
        )
        selectedOrganizationPhoneCountry = country
    }

    func submit() async {
        guard canSubmit else {
            errorMessage = "Проверьте поля формы"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await session.validAccessToken()
            var avatarURL: String?
            if let avatarData {
                avatarURL = try await api.uploadAvatar(data: avatarData, token: token)
            }

            let request = try buildRequest(avatarURL: avatarURL)
            try await api.saveProfile(request, token: token)
            self.avatarURL = avatarURL
            hasLoadedProfile = false
            session.completeProfileSetup()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMyProfileIfNeeded() async {
        guard !hasLoadedProfile, !isProfileLoading else { return }
        await loadMyProfile()
    }

    func loadMyProfile() async {
        guard !isProfileLoading else { return }
        isProfileLoading = true
        profileLoadError = nil
        defer { isProfileLoading = false }

        do {
            let token = try await session.validAccessToken()
            let profile = try await api.fetchMyProfile(token: token)
            applyProfile(profile)
            hasLoadedProfile = true
        } catch {
            profileLoadError = error.localizedDescription
        }
    }

    private func buildRequest(avatarURL: String?) throws -> ProfileUpsertRequest {
        if isVolunteer {
            guard let location = splitLocation(volunteerLocation) else {
                throw ViewModelError.invalidLocation
            }
            guard let phone = e164Number(from: volunteerPhone, country: selectedVolunteerPhoneCountry) else {
                throw ViewModelError.invalidPhone
            }

            return ProfileUpsertRequest(
                type: selectedType.apiValue,
                avatarURL: avatarURL,
                firstName: trim(firstName),
                lastName: trim(lastName),
                organizationName: nil,
                phone: phone,
                email: trim(volunteerEmail).lowercased(),
                city: location.city,
                country: location.country,
                skills: skills.filter { selectedSkills.contains($0) },
                about: trim(aboutMe).nilIfEmpty
            )
        } else {
            guard let location = splitLocation(organizationLocation) else {
                throw ViewModelError.invalidLocation
            }
            guard let phone = e164Number(from: organizationPhone, country: selectedOrganizationPhoneCountry) else {
                throw ViewModelError.invalidPhone
            }

            return ProfileUpsertRequest(
                type: selectedType.apiValue,
                avatarURL: avatarURL,
                firstName: nil,
                lastName: nil,
                organizationName: trim(organizationName),
                phone: phone,
                email: trim(organizationEmail).lowercased(),
                city: location.city,
                country: location.country,
                skills: nil,
                about: trim(aboutOrganization).nilIfEmpty
            )
        }
    }

    private func applyProfile(_ profile: ProfileResponse) {
        selectedType = profileType(from: profile)
        avatarImage = nil
        avatarData = nil
        avatarURL = profile.avatarURL

        let phone = profile.phone ?? ""
        let email = profile.email ?? ""
        let location = locationValue(city: profile.city, country: profile.country)
        let about = profile.about ?? ""

        switch selectedType {
        case .volunteer:
            firstName = profile.firstName ?? ""
            lastName = profile.lastName ?? ""
            volunteerPhone = phone
            volunteerEmail = email
            volunteerLocation = location
            selectedSkills = Set(profile.skills ?? [])
            aboutMe = about

            if let country = country(matching: phone) {
                selectedVolunteerPhoneCountry = country
            }

            organizationName = ""
            organizationPhone = ""
            organizationEmail = ""
            organizationLocation = ""
            aboutOrganization = ""

        case .organization:
            organizationName = profile.organizationName ?? ""
            organizationPhone = phone
            organizationEmail = email
            organizationLocation = location
            aboutOrganization = about

            if let country = country(matching: phone) {
                selectedOrganizationPhoneCountry = country
            }

            firstName = ""
            lastName = ""
            volunteerPhone = ""
            volunteerEmail = ""
            volunteerLocation = ""
            selectedSkills = []
            aboutMe = ""
        }
    }

    private func profileType(from profile: ProfileResponse) -> ProfileType {
        switch profile.type {
        case ProfileType.organization.apiValue, ProfileType.organization.rawValue:
            return .organization
        case ProfileType.volunteer.apiValue, ProfileType.volunteer.rawValue:
            return .volunteer
        default:
            return profile.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? .organization
                : .volunteer
        }
    }

    private func locationValue(city: String?, country: String?) -> String {
        [city, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: ", ")
    }

    private func validateEmail(_ value: String) -> String? {
        let email = trim(value)
        guard !email.isEmpty else { return nil }
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let valid = NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
        return valid ? nil : "Введите корректную почту"
    }

    private func validatePhone(_ value: String, country: PhoneCountry) -> String? {
        let digits = localDigits(from: value, fallbackCountry: country)

        if digits.isEmpty {
            return nil
        }

        if digits.count < country.localNumberLength {
            return "Номер слишком короткий"
        }

        if digits.count > country.localNumberLength {
            return "Введите корректный номер для выбранной страны"
        }

        return nil
    }

    private func validateLocation(_ value: String) -> String? {
        let value = trim(value)
        guard !value.isEmpty else { return nil }
        return splitLocation(value) == nil ? "Введите в формате: Город, Страна" : nil
    }

    private func splitLocation(_ value: String) -> (city: String, country: String)? {
        let parts = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    private func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func country(matching phone: String) -> PhoneCountry? {
        phoneCountries
            .sorted { $0.code.count > $1.code.count }
            .first { phone.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix($0.code) }
    }

    private func localDigits(from phone: String, fallbackCountry: PhoneCountry? = nil) -> String {
        var trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = country(matching: trimmed) ?? fallbackCountry

        if let country, trimmed.hasPrefix(country.code) {
            trimmed.removeFirst(country.code.count)
        }

        return trimmed.filter(\.isNumber)
    }

    private func phoneValue(
        fromLocalInput value: String,
        country: PhoneCountry,
        currentPhone: String
    ) -> String {
        let digits = value.filter(\.isNumber)
        guard digits.count <= country.localNumberLength else {
            return currentPhone
        }

        return digits.isEmpty ? "" : "\(country.code)\(digits)"
    }

    private func phoneValueAfterCountryChange(
        to country: PhoneCountry,
        currentPhone: String,
        currentCountry: PhoneCountry
    ) -> String {
        let digits = localDigits(from: currentPhone, fallbackCountry: currentCountry)
        guard !digits.isEmpty, digits.count <= country.localNumberLength else {
            return ""
        }

        return "\(country.code)\(digits)"
    }

    private func e164Number(localDigits: String, country: PhoneCountry) -> String? {
        guard localDigits.count == country.localNumberLength else { return nil }
        return "\(country.code)\(localDigits)"
    }

    private func e164Number(from phone: String, country: PhoneCountry) -> String? {
        let digits = localDigits(from: phone, fallbackCountry: country)
        return e164Number(localDigits: digits, country: country)
    }
}

enum ViewModelError: LocalizedError {
    case invalidLocation
    case invalidPhone

    var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Введите местонахождение в формате: Город, Страна"
        case .invalidPhone:
            return "Введите корректный номер для выбранной страны"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
