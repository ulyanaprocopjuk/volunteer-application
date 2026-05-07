import SwiftUI

private enum Constants {
    static let horizontalPadding: CGFloat = 30
    static let headerTopPadding: CGFloat = 160
    static let fieldsTopPadding: CGFloat = 20
    static let buttonTopPadding: CGFloat = 20
    static let bottomButtonTopPadding: CGFloat = 12

    static let headerSpacing: CGFloat = 15
    static let fieldsSpacing: CGFloat = 20

    static let fieldHPadding: CGFloat = 18
    static let fieldVPadding: CGFloat = 16

    static let fieldCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 16
}

struct LoginView: View {
    @StateObject private var vm: LoginViewModel
    @FocusState private var focusedField: Field?
    private let session: AppSession

    private enum Field: Hashable {
        case username
        case password
    }

    init(session: AppSession) {
        self.session = session
        _vm = StateObject(wrappedValue: LoginViewModel(session: session))
        FontRegistrar.registerIfNeeded()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header

                VStack(spacing: Constants.fieldsSpacing) {
                    LoginTextField(
                        placeholder: "Имя пользователя",
                        text: $vm.username,
                        focus: $focusedField,
                        field: .username,
                        keyboard: .default,
                        contentType: .username,
                        autocapitalization: .never,
                        submitLabel: .next
                    ) {
                        focusedField = .password
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LoginSecureField(
                            placeholder: "Пароль",
                            text: $vm.password,
                            focus: $focusedField,
                            field: .password,
                            contentType: .password,
                            submitLabel: .go
                        ) {
                            performLogin()
                        }

                        if let errorMessage = vm.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.top, Constants.fieldsTopPadding)

//                rememberMeToggle
//                    .padding(.top, 16)

                forgotPasswordLink
                    .padding(.top, 16)

                loginButton
                    .padding(.top, Constants.buttonTopPadding)

                bottomSignupRow
                    .padding(.top, Constants.bottomButtonTopPadding)
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white.ignoresSafeArea())
        .onChange(of: vm.username) { _, _ in
            vm.clearError()
        }
        .onChange(of: vm.password) { _, _ in
            vm.clearError()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Constants.headerSpacing) {
            Text("Вход")
                .font(.custom("NotoSans-Bold", size: 38))
                .foregroundStyle(.black)

            Text("Рады вас видеть снова!")
                .font(.custom("NotoSans-Medium", size: 18))
                .foregroundStyle(.black.opacity(0.8))
        }
        .padding(.top, Constants.headerTopPadding)
    }

//    private var rememberMeToggle: some View {
//        Button {
//            vm.rememberMe.toggle()
//        } label: {
//            HStack(spacing: 10) {
//                Image(systemName: vm.rememberMe ? "checkmark.square.fill" : "square")
//                    .font(.system(size: 20, weight: .semibold))
//                    .foregroundStyle(.black)
//
//                Text("Запомнить меня")
//                    .foregroundStyle(.black)
//
//                Spacer()
//            }
//        }
//        .buttonStyle(.plain)
//    }

    private var forgotPasswordLink: some View {
        NavigationLink {
            ForgotPasswordView()
        } label: {
            Text("Забыли пароль?")
                .font(.custom("NotoSans-Medium", size: 15))
                .underline()
                .foregroundStyle(.black.opacity(0.9))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loginButton: some View {
        Button {
            performLogin()
        } label: {
            Text("Войти")
                .font(.custom("NotoSans-Bold", size: 20))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(vm.isLoginDisabled ? Color.black.opacity(0.45) : Color.black)
                .clipShape(
                    RoundedRectangle(cornerRadius: Constants.buttonCornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(vm.isLoginDisabled || vm.isLoading)
    }

    private var bottomSignupRow: some View {
        HStack(spacing: 0) {
            Text("Еще нет аккаунта? ")
                .font(.custom("NotoSans-Medium", size: 15))
                .foregroundStyle(.black.opacity(0.85))

            NavigationLink {
                SignUpView(session: session)
            } label: {
                Text("Зарегистрироваться")
                    .font(.custom("NotoSans-Medium", size: 15))
                    .underline()
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func performLogin() {
        focusedField = nil
        Task {
            await vm.login()
        }
    }
}

// MARK: - Reusable Fields

private struct LoginTextField<FieldID: Hashable>: View {
    let placeholder: String
    @Binding var text: String

    let focus: FocusState<FieldID?>.Binding
    let field: FieldID

    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .textContentType(contentType)
            .submitLabel(submitLabel)
            .focused(focus, equals: field)
            .onSubmit { onSubmit?() }
            .padding(.horizontal, Constants.fieldHPadding)
            .padding(.vertical, Constants.fieldVPadding)
            .modifier(AuthFieldChrome())
            .foregroundStyle(.black)
    }
}

private struct LoginSecureField<FieldID: Hashable>: View {
    let placeholder: String
    @Binding var text: String

    let focus: FocusState<FieldID?>.Binding
    let field: FieldID

    var contentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                SecureField(placeholder, text: $text)
                    .textContentType(contentType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .focused(focus, equals: field)
                    .onSubmit { onSubmit?() }
                    .opacity(isSecure ? 1 : 0)
                    .allowsHitTesting(isSecure)

                TextField(placeholder, text: $text)
                    .textContentType(contentType)
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
            .accessibilityLabel(isSecure ? "Show password" : "Hide password")
        }
        .frame(minHeight: 22)
        .padding(.horizontal, Constants.fieldHPadding)
        .padding(.vertical, Constants.fieldVPadding)
        .modifier(AuthFieldChrome())
        .foregroundStyle(.black)
        .animation(.none, value: isSecure)
    }
}

private struct AuthFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Constants.fieldCornerRadius, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.fieldCornerRadius, style: .continuous)
                    .stroke(.black, lineWidth: 1)
            )
    }
}

#Preview {
    LoginView(session: AppSession())
}
