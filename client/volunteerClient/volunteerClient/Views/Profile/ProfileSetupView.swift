import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @ObservedObject private var viewModel: ProfileSetupViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(viewModel: ProfileSetupViewModel) {
        self.viewModel = viewModel

        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: 17, weight: .medium)],
            for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: UIFont.systemFont(ofSize: 17, weight: .semibold)],
            for: .selected
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Picker("Тип профиля", selection: $viewModel.selectedType) {
                    ForEach(ProfileSetupViewModel.ProfileType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
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
                    Task { await viewModel.submit() }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 44/255, green: 67/255, blue: 102/255))

                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Продолжить")
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
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGray6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: selectedPhotoItem) {
            await loadPhoto()
        }
        .alert("Сообщение", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in
                viewModel.errorMessage = nil
            }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var volunteerFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            LabeledInputField(title: "Имя", text: $viewModel.firstName, placeholder: "Введите имя")
            LabeledInputField(title: "Фамилия", text: $viewModel.lastName, placeholder: "Введите фамилию")
            LabeledInputField(title: "Номер телефона", text: $viewModel.volunteerPhone, placeholder: "Введите номер телефона", keyboardType: .phonePad)
            LabeledInputField(title: "Электронная почта", text: $viewModel.volunteerEmail, placeholder: "Введите электронную почту", keyboardType: .emailAddress, autocapitalization: .never, error: viewModel.volunteerEmailError)
            LabeledInputField(title: "Местонахождение", text: $viewModel.volunteerLocation, placeholder: "Минск, Беларусь", error: viewModel.volunteerLocationError)
            LabeledMultiSelectField(title: "Навыки", selectedValues: $viewModel.selectedSkills, options: viewModel.skills, placeholder: "Выберите навыки")
            LabeledMultilineField(title: "Обо мне", text: $viewModel.aboutMe, placeholder: "Расскажите о себе")
        }
    }

    private var organizationFields: some View {
        VStack(alignment: .leading, spacing: 22) {
            LabeledInputField(title: "Название организации", text: $viewModel.organizationName, placeholder: "Введите название организации")
            LabeledInputField(title: "Телефон", text: $viewModel.organizationPhone, placeholder: "Введите номер телефона", keyboardType: .phonePad)
            LabeledInputField(title: "Электронная почта", text: $viewModel.organizationEmail, placeholder: "Введите электронную почту", keyboardType: .emailAddress, autocapitalization: .never, error: viewModel.organizationEmailError)
            LabeledInputField(title: "Местонахождение", text: $viewModel.organizationLocation, placeholder: "Минск, Беларусь", error: viewModel.organizationLocationError)
            LabeledMultilineField(title: "О нас", text: $viewModel.aboutOrganization, placeholder: "Расскажите об организации")
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
                } else {
                    Circle()
                        .fill(Color(red: 231/255, green: 243/255, blue: 247/255))
                        .frame(width: 104, height: 104)

                    Image(systemName: isVolunteer ? "person.fill" : "building.2.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
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

#Preview {
    NavigationStack {
        ProfileSetupView(
            viewModel: ProfileSetupViewModel(
                session: AppSession()
            )
        )
    }
}
