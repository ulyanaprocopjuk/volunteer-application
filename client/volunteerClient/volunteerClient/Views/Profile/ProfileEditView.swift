import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @ObservedObject private var viewModel: ProfileSetupViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var originalSnapshot: ProfileSetupViewModel.ProfileSnapshot?
    @State private var didPrepare = false

    var onBack: () -> Void = {}
    var onSave: () -> Void = {}

    init(
        viewModel: ProfileSetupViewModel,
        onBack: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onSave = onSave
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                avatarSection
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 22) {
                    if viewModel.isVolunteer {
                        volunteerFields
                    } else {
                        organizationFields
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Button {
                    Task {
                        let success = await viewModel.saveProfileChanges(reloadAfterSave: true)
                        if success {
                            onSave()
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Сохранить")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .disabled(!viewModel.canSubmit || viewModel.isLoading)
                .opacity((!viewModel.canSubmit || viewModel.isLoading) ? 0.55 : 1)
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 24)
            }
            .padding(.bottom, 18)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .task {
            await prepareIfNeeded()
        }
        .task(id: selectedPhotoItem) {
            await loadPhoto()
        }
        .alert("Сообщение", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var headerSection: some View {
        HStack {
            Button {
                if let originalSnapshot {
                    viewModel.restoreProfileSnapshot(originalSnapshot)
                }
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(Color.white.opacity(0.96))
                    )
                    .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Редактирование")
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.85))

            Spacer()

            Color.clear
                .frame(width: 42, height: 42)
        }
    }

    private var volunteerFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            LabeledInputField(title: "Имя", text: $viewModel.firstName, placeholder: "Введите имя")
            LabeledInputField(title: "Фамилия", text: $viewModel.lastName, placeholder: "Введите фамилию")
            LabeledPhoneField(
                title: "Номер телефона",
                localNumber: Binding(
                    get: { viewModel.volunteerLocalPhoneNumber },
                    set: { viewModel.setVolunteerLocalPhoneNumber($0) }
                ),
                selectedCountry: viewModel.selectedVolunteerPhoneCountry,
                countries: viewModel.phoneCountries,
                error: viewModel.volunteerPhoneError,
                onSelectCountry: { viewModel.selectVolunteerPhoneCountry($0) }
            )
            LabeledInputField(
                title: "Электронная почта",
                text: $viewModel.volunteerEmail,
                placeholder: "Введите электронную почту",
                keyboardType: .emailAddress,
                autocapitalization: .never,
                error: viewModel.volunteerEmailError
            )
            LabeledInputField(
                title: "Местонахождение",
                text: $viewModel.volunteerLocation,
                placeholder: "Минск, Беларусь",
                error: viewModel.volunteerLocationError
            )
            LabeledMultiSelectField(
                title: "Навыки",
                selectedValues: $viewModel.selectedSkills,
                options: viewModel.skills,
                placeholder: "Выберите навыки"
            )
            LabeledMultilineField(
                title: "Обо мне",
                text: $viewModel.aboutMe,
                placeholder: "Расскажите о себе"
            )
        }
    }

    private var organizationFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            LabeledInputField(
                title: "Название организации",
                text: $viewModel.organizationName,
                placeholder: "Введите название организации"
            )
            LabeledPhoneField(
                title: "Телефон",
                localNumber: Binding(
                    get: { viewModel.organizationLocalPhoneNumber },
                    set: { viewModel.setOrganizationLocalPhoneNumber($0) }
                ),
                selectedCountry: viewModel.selectedOrganizationPhoneCountry,
                countries: viewModel.phoneCountries,
                error: viewModel.organizationPhoneError,
                onSelectCountry: { viewModel.selectOrganizationPhoneCountry($0) }
            )
            LabeledInputField(
                title: "Электронная почта",
                text: $viewModel.organizationEmail,
                placeholder: "Введите электронную почту",
                keyboardType: .emailAddress,
                autocapitalization: .never,
                error: viewModel.organizationEmailError
            )
            LabeledInputField(
                title: "Местонахождение",
                text: $viewModel.organizationLocation,
                placeholder: "Минск, Беларусь",
                error: viewModel.organizationLocationError
            )
            LabeledMultilineField(
                title: "О нас",
                text: $viewModel.aboutOrganization,
                placeholder: "Расскажите об организации"
            )
        }
    }

    private var avatarSection: some View {
        let avatarImage = viewModel.avatarImage
        let isVolunteer = viewModel.isVolunteer

        return PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack {
                if let avatar = avatarImage {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                } else if let remoteURL = avatarRemoteURL {
                    AsyncImage(url: remoteURL) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Color(red: 231/255, green: 243/255, blue: 247/255))
                                .frame(width: 104, height: 104)
                                .overlay {
                                    ProgressView()
                                        .tint(Color(red: 18/255, green: 162/255, blue: 231/255))
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 104, height: 104)
                                .clipShape(Circle())
                        case .failure:
                            placeholderAvatar(isVolunteer: isVolunteer)
                        @unknown default:
                            placeholderAvatar(isVolunteer: isVolunteer)
                        }
                    }
                } else {
                    placeholderAvatar(isVolunteer: isVolunteer)
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

    @ViewBuilder
    private func placeholderAvatar(isVolunteer: Bool) -> some View {
        Circle()
            .fill(Color(red: 231/255, green: 243/255, blue: 247/255))
            .frame(width: 104, height: 104)
            .overlay {
                Image(systemName: isVolunteer ? "person.fill" : "building.2.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(Color(red: 18/255, green: 162/255, blue: 231/255))
            }
    }

    private var avatarRemoteURL: URL? {
        guard let avatarURL = viewModel.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !avatarURL.isEmpty else {
            return nil
        }

        if let url = URL(string: avatarURL), url.scheme != nil {
            return url
        }

        guard let baseURL = URL(string: AppConfig.baseURLString) else {
            return nil
        }

        let path = avatarURL.hasPrefix("/") ? String(avatarURL.dropFirst()) : avatarURL
        return baseURL.appendingPathComponent(path)
    }

    private func prepareIfNeeded() async {
        guard !didPrepare else { return }
        await viewModel.loadMyProfileIfNeeded()
        originalSnapshot = viewModel.makeProfileSnapshot()
        didPrepare = true
    }

    private func loadPhoto() async {
        guard let selectedPhotoItem else { return }
        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                viewModel.errorMessage = "Не удалось загрузить фото"
                return
            }
            viewModel.setAvatar(image)
        } catch {
            viewModel.errorMessage = "Не удалось открыть фото"
        }
    }
}
