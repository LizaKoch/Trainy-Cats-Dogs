import SwiftUI

/// Экран сброса пароля: отправляет письмо со ссылкой через Firebase.
/// Саму установку нового пароля пользователь делает на странице по этой ссылке —
/// отдельный экран внутри приложения для этого не нужен.
struct ForgotPasswordView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var didSend = false

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    private var canSubmit: Bool {
        !email.isEmpty && !auth.isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Theme.accentGradient)
                                .frame(width: 72, height: 72)
                            Image(systemName: "key.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }
                        Text("Сброс пароля")
                            .font(.title2.bold())
                        Text("Укажи email — пришлём ссылку, по которой можно задать новый пароль.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let status = auth.statusMessage {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                            .multilineTextAlignment(.center)
                    }
                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            let sent = await auth.sendPasswordReset(email: email)
                            if sent { didSend = true }
                        }
                    } label: {
                        HStack {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            }
                            Text(didSend ? "Отправить ещё раз" : "Отправить ссылку")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!canSubmit)

                    if didSend {
                        Text("Открой письмо и перейди по ссылке — там можно задать новый пароль. Потом вернись сюда и войди с ним.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Забыли пароль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        auth.errorMessage = nil
                        auth.statusMessage = nil
                        dismiss()
                    }
                }
            }
            .animation(.default, value: auth.statusMessage)
            .animation(.default, value: auth.errorMessage)
        }
    }
}

#Preview {
    ForgotPasswordView(email: "test@example.com")
        .environmentObject(AuthService())
}
