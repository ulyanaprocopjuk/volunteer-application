import SwiftUI

private enum Constants {
    static let horizontalPadding: CGFloat = 35
    static let headerTopPadding: CGFloat = 160
    static let fieldsTopPadding: CGFloat = 20
    static let buttonTopPadding: CGFloat = 20
    static let bottomButtonTopPadding: CGFloat = 12

    static let headerSpacing: CGFloat = 15
    static let fieldsSpacing: CGFloat = 20

    static let fieldHPadding: CGFloat = 18
    static let fieldVPadding: CGFloat = 14

    static let fieldCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 16
}

struct SignUpView: View {
    @StateObject private var vm = SignUpViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username
        case password
        case confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header

                VStack(spacing: Constants.fieldsSpacing) {
                    SignUpTextField(
                        placeholder: "Username",
                        text: $vm.username,
                        focus: $focusedField,
                        field: .username,
                        contentType: .username,
                        autocapitalization: .never,
                        submitLabel: .next
                    ) {
                        focusedField = .password
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SignUpSecureField(
                            placeholder: "Password",
                            text: $vm.password,
                            focus: $focusedField,
                            field: .password,
                            contentType: .newPassword,
                            submitLabel: .next
                        ) {
                            focusedField = .confirmPassword
                        }

                        if !vm.password.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                if vm.passwordValidationErrors.isEmpty {
                                    Text("Пароль соответствует требованиям")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    ForEach(vm.passwordValidationErrors, id: \.self) { error in
                                        Text("• \(error)")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SignUpSecureField(
                            placeholder: "Confirm Password",
                            text: $vm.confirmPassword,
                            focus: $focusedField,
                            field: .confirmPassword,
                            contentType: .newPassword,
                            submitLabel: .go
                        ) {
                            performSignUp()
                        }

                        if let mismatch = vm.confirmPasswordError {
                            Text(mismatch)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.top, Constants.fieldsTopPadding)

                if let signUpError = vm.signUpError {
                    Text(signUpError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                }

                signUpButton
                    .padding(.top, Constants.buttonTopPadding)

                bottomLoginRow
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
        .onChange(of: vm.username) { newValue in
            vm.username = newValue.replacingOccurrences(of: " ", with: "")
            vm.clearServerError()
        }
        
        .onChange(of: vm.password) { _ in
            vm.clearServerError()
        }
        .onChange(of: vm.confirmPassword) { _ in
            vm.clearServerError()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Constants.headerSpacing) {
            Text("Signup")
                .font(.custom("NotoSans-Bold", size: 38))
                .foregroundStyle(.black)

            Text("Just some details to get you in.!")
                .font(.custom("NotoSans-Medium", size: 18))
                .foregroundStyle(.black.opacity(0.8))
        }
        .padding(.top, Constants.headerTopPadding)
    }

    private struct PasswordRuleRow: View {
        let title: String
        let isSatisfied: Bool

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: isSatisfied ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSatisfied ? .green : .gray.opacity(0.7))

                Text(title)
                    .font(.caption)
                    .foregroundStyle(isSatisfied ? .black.opacity(0.85) : .gray)

                Spacer(minLength: 0)
            }
            .animation(.easeInOut(duration: 0.15), value: isSatisfied)
        }
    }

    private var signUpButton: some View {
        Button {
            performSignUp()
        } label: {
            Text("Signup")
                .font(.custom("NotoSans-Bold", size: 20))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(vm.isSignUpDisabled ? Color.black.opacity(0.45) : Color.black)
                .clipShape(
                    RoundedRectangle(cornerRadius: Constants.buttonCornerRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(vm.isSignUpDisabled || vm.isLoading)
    }

    private var bottomLoginRow: some View {
        HStack(spacing: 0) {
            Text("Already registered? ")
                .font(.custom("NotoSans-Medium", size: 15))
                .foregroundStyle(.black.opacity(0.85))

            Button {
                // TODO: navigate to login
            } label: {
                Text("Login")
                    .font(.custom("NotoSans-Medium", size: 15))
                    .underline()
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func performSignUp() {
        focusedField = nil
        Task {
            _ = await vm.signUp()
        }
    }
}

// MARK: - Reusable Fields

private struct SignUpTextField<FieldID: Hashable>: View {
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

private struct SignUpSecureField<FieldID: Hashable>: View {
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
    SignUpView()
}
