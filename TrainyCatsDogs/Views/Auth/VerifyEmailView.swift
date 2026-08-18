import SwiftUI
import Combine

/// Показывается пользователю, который зарегистрировался по email/паролю, но ещё не перешёл
/// по ссылке подтверждения из письма. Позволяет перепроверить статус и отправить письмо заново.
struct VerifyEmailView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var cooldown = 60

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

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
                    Task { await auth.reloadEmailVerificationStatus() }
                } label: {
                    HStack {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        }
                        Text("Я подтвердила почту")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(auth.isLoading)

                Button {
                    Task { await auth.resendVerificationEmail() }
                    cooldown = 60
                } label: {
                    Text(cooldown > 0 ? "Отправить ещё раз (\(cooldown) с)" : "Отправить письмо ещё раз")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(auth.isLoading || cooldown > 0)

                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Text("Выйти и указать другую почту")
                        .font(.footnote)
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            Task { await auth.reloadEmailVerificationStatus() }
        }
        .onReceive(ticker) { _ in
            if cooldown > 0 { cooldown -= 1 }
        }
        .animation(.default, value: auth.statusMessage)
        .animation(.default, value: auth.errorMessage)
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 84, height: 84)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }
            Text("Подтверди почту")
                .font(.largeTitle.bold())
            if let email = auth.user?.email {
                Text("Мы отправили ссылку на \(email). Перейди по ней в почте, потом вернись сюда и нажми «Я подтвердила почту».")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 32)
    }
}

#Preview {
    VerifyEmailView()
        .environmentObject(AuthService())
}
