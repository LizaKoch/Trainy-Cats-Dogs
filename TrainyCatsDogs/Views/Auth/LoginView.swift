import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && !auth.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    SecureField("Пароль (минимум 6 символов)", text: $password)
                        .textContentType(isSignUpMode ? .newPassword : .password)
                        .focused($focusedField, equals: .password)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if !isSignUpMode {
                        HStack {
                            Spacer()
                            Button("Забыли пароль?") {
                                focusedField = nil
                                auth.errorMessage = nil
                                auth.statusMessage = nil
                                showForgotPassword = true
                            }
                            .font(.footnote)
                        }
                    }
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Button {
                    focusedField = nil
                    Task {
                        if isSignUpMode {
                            await auth.signUp(email: email, password: password)
                        } else {
                            await auth.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    HStack {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(isSignUpMode ? "Зарегистрироваться" : "Войти")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canSubmit)

                separator

                Button {
                    focusedField = nil
                    auth.signInWithGoogle()
                } label: {
                    HStack {
                        Image(systemName: "globe")
                        Text("Войти через Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(auth.isLoading)

                Button {
                    withAnimation { isSignUpMode.toggle() }
                    auth.errorMessage = nil
                } label: {
                    Text(isSignUpMode ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Зарегистрироваться")
                        .font(.footnote)
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.default, value: auth.errorMessage)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: email)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 84, height: 84)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            Text("Trainy")
                .font(.largeTitle.bold())
            Text(isSignUpMode ? "Создай аккаунт, чтобы начать тренировки" : "Войди, чтобы продолжить тренировки")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if isSignUpMode {
                Text("После регистрации пришлём письмо со ссылкой для подтверждения почты.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 32)
    }

    private var separator: some View {
        HStack {
            VStack { Divider() }
            Text("или").font(.caption).foregroundStyle(.secondary)
            VStack { Divider() }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
