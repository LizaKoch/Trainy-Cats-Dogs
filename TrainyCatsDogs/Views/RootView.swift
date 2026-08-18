import SwiftUI

/// Точка ветвления: экран входа → (для email/пароля) экран подтверждения почты →
/// основное приложение. Вход через Google минует подтверждение — Google уже проверил почту.
struct RootView: View {
    @StateObject private var auth = AuthService()

    var body: some View {
        Group {
            if auth.user == nil {
                LoginView()
            } else if !auth.isEmailVerified {
                VerifyEmailView()
            } else {
                ContentView()
            }
        }
        .environmentObject(auth)
        .animation(.default, value: auth.user == nil)
        .animation(.default, value: auth.isEmailVerified)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Dog.self, Exercise.self, TrainingSession.self], inMemory: true)
}
