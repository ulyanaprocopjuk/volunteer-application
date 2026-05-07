import SwiftUI
import Combine

@MainActor
final class NewPasswordViewModel: ObservableObject {
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var didSave = false
    @Published var errorMessage: String?

    let resetToken: String
    private let authAPI: AuthAPIProtocol

    init(resetToken: String, authAPI: AuthAPIProtocol? = nil) {
        self.resetToken = resetToken
        self.authAPI = authAPI ?? AuthAPI()
    }

    var passwordValidationErrors: [String] {
        var errors: [String] = []
        if password.count < 8 { errors.append("Минимум 8 символов") }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil { errors.append("Хотя бы одна заглавная буква") }
        if password.rangeOfCharacter(from: .decimalDigits) == nil { errors.append("Хотя бы одна цифра") }
        return errors
    }

    var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty else { return nil }
        return password == confirmPassword ? nil : "Пароли не совпадают"
    }

    var canSave: Bool {
        passwordValidationErrors.isEmpty && password == confirmPassword && !confirmPassword.isEmpty
    }

    func save() async {
        guard canSave else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await authAPI.resetPassword(token: resetToken, newPassword: password)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NewPasswordView: View {
    @StateObject private var vm: NewPasswordViewModel
    @FocusState private var focusedField: Field?
    @EnvironmentObject private var session: AppSession

    private enum Field: Hashable {
        case password, confirmPassword
    }

    init(resetToken: String) {
        _vm = StateObject(wrappedValue: NewPasswordViewModel(resetToken: resetToken))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 190)

                if vm.didSave {
                    successSection
                        .padding(.top, 32)
                } else {
                    fields
                        .padding(.top, 32)

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                            .padding(.horizontal, 4)
                    }

                    saveButton
                        .padding(.top, 30)
                }
            }
            .padding(.horizontal, 30)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Новый пароль")
                .font(.custom("NotoSans-SemiBold", size: 32))
                .foregroundStyle(.black)

            Text("Придумайте надёжный пароль для вашего аккаунта")
                .font(.custom("NotoSans-Medium", size: 18))
                .foregroundStyle(.black.opacity(0.7))
        }
    }

    private var fields: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                NewPasswordSecureField(
                    placeholder: "Новый пароль",
                    text: $vm.password,
                    focus: $focusedField,
                    field: .password,
                    submitLabel: .next
                ) {
                    focusedField = .confirmPassword
                }

                if !vm.password.isEmpty {
                    if vm.passwordValidationErrors.isEmpty {
                        Text("Пароль соответствует требованиям")
                            .font(.caption).foregroundStyle(.green)
                    } else {
                        ForEach(vm.passwordValidationErrors, id: \.self) { e in
                            Text("• \(e)").font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                NewPasswordSecureField(
                    placeholder: "Подтвердите пароль",
                    text: $vm.confirmPassword,
                    focus: $focusedField,
                    field: .confirmPassword,
                    submitLabel: .go
                ) {
                    Task { await vm.save() }
                }

                if let mismatch = vm.confirmPasswordError {
                    Text(mismatch).font(.caption).foregroundStyle(.red).padding(.horizontal, 4)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            focusedField = nil
            Task { await vm.save() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(vm.canSave ? Color.black : Color.black.opacity(0.45))
                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Сохранить пароль")
                        .font(.custom("NotoSans-Bold", size: 20))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canSave || vm.isLoading)
    }

    private var successSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                    Text("Пароль изменён!")
                        .font(.custom("NotoSans-Bold", size: 18))
                        .foregroundStyle(.black)
                }
                Text("Теперь вы можете войти с новым паролем.")
                    .font(.custom("NotoSans-Medium", size: 15))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.08))
            )

            Button {
                session.pendingPasswordResetToken = nil
            } label: {
                Text("Перейти ко входу")
                    .font(.custom("NotoSans-Bold", size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NewPasswordSecureField<FieldID: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    let focus: FocusState<FieldID?>.Binding
    let field: FieldID
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                SecureField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .focused(focus, equals: field)
                    .onSubmit { onSubmit?() }
                    .opacity(isSecure ? 1 : 0)
                    .allowsHitTesting(isSecure)

                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .focused(focus, equals: field)
                    .onSubmit { onSubmit?() }
                    .opacity(isSecure ? 0 : 1)
                    .allowsHitTesting(!isSecure)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isSecure.toggle()
                focus.wrappedValue = field
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundStyle(.black.opacity(0.7))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 22)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.black, lineWidth: 1))
        .foregroundStyle(.black)
        .animation(.none, value: isSecure)
    }
}

#Preview {
    NewPasswordView(resetToken: "preview-token")
        .environmentObject(AppSession())
}
