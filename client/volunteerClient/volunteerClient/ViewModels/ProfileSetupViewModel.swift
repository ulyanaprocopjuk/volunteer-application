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

    @Published var selectedType: ProfileType = .volunteer
    @Published var avatarImage: UIImage?
    private var avatarData: Data?

    @Published var firstName = ""
    @Published var lastName = ""
    @Published var volunteerPhone = ""
    @Published var volunteerEmail = ""
    @Published var volunteerLocation = ""
    @Published var selectedSkills: Set<String> = []
    @Published var aboutMe = ""

    @Published var organizationName = ""
    @Published var organizationPhone = ""
    @Published var organizationEmail = ""
    @Published var organizationLocation = ""
    @Published var aboutOrganization = ""

    @Published var isLoading = false
    @Published var errorMessage: String?

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

    var volunteerEmailError: String? {
        validateEmail(volunteerEmail)
    }

    var organizationEmailError: String? {
        validateEmail(organizationEmail)
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
                volunteerEmailError == nil &&
                volunteerLocationError == nil
        } else {
            return !trim(organizationName).isEmpty &&
                !trim(organizationPhone).isEmpty &&
                !trim(organizationEmail).isEmpty &&
                !trim(organizationLocation).isEmpty &&
                organizationEmailError == nil &&
                organizationLocationError == nil
        }
    }

    func setAvatar(_ image: UIImage) {
        avatarImage = image
        avatarData = image.jpegData(compressionQuality: 0.82)
    }

    func submit() async {
        guard canSubmit else {
            errorMessage = "Проверьте поля формы"
            return
        }

        guard let token = session.token, !token.isEmpty else {
            errorMessage = "Пользователь не авторизован"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var avatarURL: String?
            if let avatarData {
                avatarURL = try await api.uploadAvatar(data: avatarData, token: token)
            }

            let request = try buildRequest(avatarURL: avatarURL)
            try await api.saveProfile(request, token: token)
            session.completeProfileSetup()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildRequest(avatarURL: String?) throws -> ProfileUpsertRequest {
        if isVolunteer {
            guard let location = splitLocation(volunteerLocation) else {
                throw ViewModelError.invalidLocation
            }

            return ProfileUpsertRequest(
                type: selectedType.apiValue,
                avatarURL: avatarURL,
                firstName: trim(firstName),
                lastName: trim(lastName),
                organizationName: nil,
                phone: trim(volunteerPhone),
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

            return ProfileUpsertRequest(
                type: selectedType.apiValue,
                avatarURL: avatarURL,
                firstName: nil,
                lastName: nil,
                organizationName: trim(organizationName),
                phone: trim(organizationPhone),
                email: trim(organizationEmail).lowercased(),
                city: location.city,
                country: location.country,
                skills: nil,
                about: trim(aboutOrganization).nilIfEmpty
            )
        }
    }

    private func validateEmail(_ value: String) -> String? {
        let email = trim(value)
        guard !email.isEmpty else { return nil }
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let valid = NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
        return valid ? nil : "Введите корректную почту"
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
}

enum ViewModelError: LocalizedError {
    case invalidLocation

    var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Введите местонахождение в формате: Город, Страна"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
