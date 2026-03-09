import SwiftUI

private enum Constants {

    static let HorizontalPadding: CGFloat = 30
    static let headerTopPadding: CGFloat = 40
    static let fieldsTopPadding: CGFloat = 20
    static let buttonTopPadding: CGFloat = 20
    static let BottomButtonTopPadding: CGFloat = 12

    static let headerSpacing: CGFloat = 15
    static let fieldsSpacing: CGFloat = 20

    static let fieldHPadding: CGFloat = 18
    static let fieldVPadding: CGFloat = 16
}

struct ProfileSetupView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var mobileNumber = ""
    @State private var email = ""


    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Profile Setup")
                    .font(.custom("Kadwa-Bold", size: 16))
                    .foregroundColor(Color.grey300)
                    .padding(.top, Constants.headerTopPadding)
            }
            VStack(alignment: .leading, spacing: Constants.fieldsSpacing) {
                ProfileSetupTextField(placeholder: "Enter First Name", text: $firstName)
                ProfileSetupTextField(placeholder: "Enter Last Name", text: $lastName)
                ProfileSetupTextField(placeholder: "Enter Mobile Number", text: $mobileNumber)
                ProfileSetupTextField(placeholder: "Enter your Email", text: $email)
                ProfileSetupTextField(placeholder: "Enter Mobile Number", text: $mobileNumber)


            }
        }
    }
}

private struct ProfileSetupTextField: View {
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

#Preview {
    ProfileSetupView()
}
