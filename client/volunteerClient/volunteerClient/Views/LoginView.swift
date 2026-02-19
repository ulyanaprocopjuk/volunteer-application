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
}

struct LoginView: View {
    @State private var fullName = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @AppStorage("rememberMe") private var rememberMe = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                    Text("Login")
                        .font(.custom("NotoSans-Bold", size: 38))
                        .foregroundStyle(.black)

                    Text("Glad you're back!")
                        .font(.custom("NotoSans-Medium", size: 18))
                        .foregroundStyle(.black.opacity(0.8))
                }
                .padding(.top, Constants.headerTopPadding)

                VStack(spacing: Constants.fieldsSpacing) {
                    LoginTextField(placeholder: "Username", text: $fullName)
                    LoginSecureField(placeholder: "Password", text: $password)
                }
                .padding(.top, Constants.fieldsTopPadding)

                Button {
                    rememberMe.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)

                        Text("Remember me")
                            .foregroundStyle(.black)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                Button {
                    // TODO: signup action
                } label: {
                    Text("Login")
                        .font(.custom("NotoSans-Bold", size: 20))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, Constants.buttonTopPadding)

                HStack(spacing: 0) {
                    Text("Don't have an account? ")
                        .font(.custom("NotoSans-Medium", size: 15))
                        .foregroundStyle(.black.opacity(0.85))
                    Button {
                        // TODO: navigate to login
                    } label: {
                        Text("Sign up")
                            .font(.custom("NotoSans-Medium", size: 15))
                            .underline()
                            .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Constants.bottomButtonTopPadding)
            }
            .padding(.horizontal, Constants.horizontalPadding)
        }
        .background(Color.white.ignoresSafeArea())
    }
}

private struct LoginTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .padding(.horizontal, Constants.fieldHPadding)
            .padding(.vertical, Constants.fieldVPadding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.white))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.black, lineWidth: 1)
            )
            .foregroundStyle(.black)
    }
}

private struct LoginSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecure = true

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundStyle(.black.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.black, lineWidth: 1)
        )
        .foregroundStyle(.black)
    }
}

#Preview {
    LoginView()
}
