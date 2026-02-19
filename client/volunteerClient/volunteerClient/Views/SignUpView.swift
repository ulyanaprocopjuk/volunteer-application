import SwiftUI

private enum Constants {

    static let HorizontalPadding: CGFloat = 30
    static let headerTopPadding: CGFloat = 160
    static let fieldsTopPadding: CGFloat = 20
    static let buttonTopPadding: CGFloat = 20
    static let BottomButtonTopPadding: CGFloat = 12

    static let headerSpacing: CGFloat = 15
    static let fieldsSpacing: CGFloat = 20

    static let fieldHPadding: CGFloat = 18
    static let fieldVPadding: CGFloat = 16
}

struct SignUpView: View {
    @State private var fullName = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: Constants.headerSpacing) {
                    Text("Signup")
                        .font(.custom("NotoSans-Bold", size: 38))
                        .foregroundStyle(.black)

                    Text("Just some details to get you in.!")
                        .font(.custom("NotoSans-Medium", size: 18))
                        .foregroundStyle(.black.opacity(0.8))
                }
                .padding(.top, Constants.headerTopPadding)

                VStack(spacing: Constants.fieldsSpacing) {
                    SignupTextField(placeholder: "Full Name", text: $fullName)
                    SignupSecureField(placeholder: "Password", text: $password)
                    SignupSecureField(placeholder: "Confirm Password", text: $confirmPassword)
                }
                .padding(.top, Constants.fieldsTopPadding)

                Button {
                    // TODO: signup action
                } label: {
                    Text("Signup")
                        .font(.custom("NotoSans-Bold", size: 20))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, Constants.buttonTopPadding)

                HStack(spacing: 0) {
                    Text("Already Registered? ")
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
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Constants.BottomButtonTopPadding)
            }
            .padding(.horizontal, Constants.HorizontalPadding)
        }
        .background(Color.white.ignoresSafeArea())
    }
}

private struct SignupTextField: View {
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

private struct SignupSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
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

#Preview {
    SignUpView()
}
