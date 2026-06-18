import SwiftUI
import Combine

@MainActor
final class ForgotPasswordViewModel: ObservableObject {
    @Published var email = ""
    @Published var isLoading = false
    @Published var didSend = false
    @Published var errorMessage: String?

    private let authAPI: AuthAPIProtocol

    init(authAPI: AuthAPIProtocol? = nil) {
        self.authAPI = authAPI ?? AuthAPI()
    }

    var emailError: String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let valid = NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
        return valid ? nil : "Введите корректную почту"
    }

    var canSend: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && emailError == nil
    }

    func send() async {
        guard canSend else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await authAPI.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            didSend = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ForgotPasswordView: View {
    @StateObject private var vm = ForgotPasswordViewModel()
    @FocusState private var isEmailFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 120)

                emailField
                    .padding(.top, 32)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                }

                sendButton
                    .padding(.top, 20)

                if vm.didSend {
                    successMessage
                        .padding(.top, 20)

                    NavigationLink {
                        NewPasswordView(email: vm.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                    } label: {
                        Text("Ввести код →")
                            .font(.custom("NotoSans-Bold", size: 18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 44/255, green: 67/255, blue: 102/255))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }

                backRow
                    .padding(.top, 16)
            }
            .padding(.horizontal, 30)
            .contentShape(Rectangle())
            .onTapGesture { isEmailFocused = false }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Забыли пароль?")
                .font(.custom("NotoSans-Bold", size: 32))
                .foregroundStyle(.black)

            Text("Укажите почту — пришлём код для сброса")
                .font(.custom("NotoSans-Medium", size: 16))
                .foregroundStyle(.black.opacity(0.7))
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Электронная почта", text: $vm.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isEmailFocused)
                .onSubmit { Task { await vm.send() } }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.black, lineWidth: 1)
                )
                .foregroundStyle(.black)
                .disabled(vm.didSend)

            if let emailErr = vm.emailError {
                Text(emailErr)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var sendButton: some View {
        Button {
            isEmailFocused = false
            Task { await vm.send() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill((vm.canSend && !vm.didSend) ? Color.black : Color.black.opacity(0.35))
                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(vm.didSend ? "Код отправлен" : "Отправить код")
                        .font(.custom("NotoSans-Bold", size: 20))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(!vm.canSend || vm.isLoading || vm.didSend)
    }

    private var successMessage: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(red: 44/255, green: 67/255, blue: 102/255))

            Text("Если почта зарегистрирована, вы получите письмо с кодом.")
                .font(.custom("NotoSans-Medium", size: 14))
                .foregroundStyle(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 44/255, green: 67/255, blue: 102/255).opacity(0.08))
        )
    }

    private var backRow: some View {
        Button {
            dismiss()
        } label: {
            Text("← Вернуться к входу")
                .font(.custom("NotoSans-Medium", size: 14))
                .underline()
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
