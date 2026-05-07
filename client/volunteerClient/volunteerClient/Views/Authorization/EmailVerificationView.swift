import SwiftUI
import Combine

@MainActor
final class EmailVerificationViewModel: ObservableObject {
    @Published var code = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var resendCooldown = 0

    private let authAPI: AuthAPIProtocol
    private unowned let session: AppSession
    private var cooldownTask: Task<Void, Never>?

    init(session: AppSession, authAPI: AuthAPIProtocol? = nil) {
        self.session = session
        self.authAPI = authAPI ?? AuthAPI()
    }

    deinit {
        cooldownTask?.cancel()
    }

    func sendCode() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }
        errorMessage = nil

        do {
            try await session.performAuthorizedRequest { token in
                try await self.authAPI.sendVerificationCode(token: token)
            }
            startCooldown(seconds: 60)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verify() async {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.count == 6 else {
            errorMessage = "Введите 6-значный код"
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await session.performAuthorizedRequest { token in
                try await self.authAPI.verifyEmail(code: trimmedCode, token: token)
            }
            session.completeEmailVerification()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startCooldown(seconds: Int) {
        resendCooldown = seconds
        cooldownTask?.cancel()
        cooldownTask = Task {
            var remaining = seconds
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                remaining -= 1
                resendCooldown = remaining
            }
        }
    }
}

struct EmailVerificationView: View {
    @StateObject private var vm: EmailVerificationViewModel
    @FocusState private var isCodeFocused: Bool
    private let session: AppSession

    init(session: AppSession) {
        self.session = session
        _vm = StateObject(wrappedValue: EmailVerificationViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 190)

                codeField
                    .padding(.top, 20)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                }

                verifyButton
                    .padding(.top, 20)

                resendRow
                    .padding(.top, 16)
            }
            .padding(.horizontal, 30)
            .contentShape(Rectangle())
            .onTapGesture { isCodeFocused = false }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white.ignoresSafeArea())
        .task {
            await vm.sendCode()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Подтвердите почту")
                .font(.custom("NotoSans-SemiBold", size: 32))
                .foregroundStyle(.black)

            Text("Мы отправили код на вашу почту. Введите его ниже.")
                .font(.custom("NotoSans-Medium", size: 18))
                .foregroundStyle(.black.opacity(0.7))
        }
    }

    private var codeField: some View {
        TextField("Код подтверждения", text: $vm.code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isCodeFocused)
            .font(.custom("NotoSans-Medium", size: 16))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.black, lineWidth: 1)
            )
            .foregroundStyle(.black)
            .onChange(of: vm.code) { _, newValue in
                vm.code = String(newValue.filter(\.isNumber).prefix(6))
            }
    }

    private var verifyButton: some View {
        Button {
            isCodeFocused = false
            Task { await vm.verify() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(vm.code.count == 6 ? Color.black : Color.black.opacity(0.45))

                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Подтвердить")
                        .font(.custom("NotoSans-Bold", size: 20))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(vm.code.count != 6 || vm.isLoading)
    }

    private var resendRow: some View {
        HStack(spacing: 0) {
            if vm.resendCooldown > 0 {
                Text("Отправить повторно через \(vm.resendCooldown) сек.")
                    .font(.custom("NotoSans-Medium", size: 14))
                    .foregroundStyle(.black.opacity(0.5))
            } else {
                Button {
                    Task { await vm.sendCode() }
                } label: {
                    Text(vm.isSending ? "Отправка..." : "Отправить код повторно")
                        .font(.custom("NotoSans-Medium", size: 14))
                        .underline()
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .disabled(vm.isSending)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    EmailVerificationView(session: AppSession())
}
