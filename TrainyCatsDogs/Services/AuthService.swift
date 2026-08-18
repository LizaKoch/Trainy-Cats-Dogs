import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// Оборачивает Firebase Auth: вход/регистрация по email+паролю (с подтверждением почты
/// по ссылке) и вход через Google. Публикует текущего пользователя и статус подтверждения
/// почты, чтобы RootView мог показывать нужный экран: вход, подтверждение почты или приложение.
@MainActor
final class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isEmailVerified = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var isLoading = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isEmailVerified = user?.isEmailVerified ?? false
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func signIn(email: String, password: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isEmailVerified = result.user.isEmailVerified
        } catch {
            errorMessage = Self.friendlyMessage(error)
        }
        isLoading = false
    }

    /// Отправляет письмо со ссылкой для сброса пароля. Саму установку нового пароля
    /// Firebase делает на своей странице по ссылке — код в приложении для этого не нужен.
    /// Возвращает true, если письмо успешно отправлено.
    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            statusMessage = "Письмо для сброса пароля отправлено на \(email)."
            isLoading = false
            return true
        } catch {
            errorMessage = Self.friendlyMessage(error)
            isLoading = false
            return false
        }
    }

    /// Регистрация по email/паролю. Сразу после создания аккаунта отправляет письмо
    /// со ссылкой подтверждения — доступ к приложению откроется только после перехода по ней.
    func signUp(email: String, password: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try? await result.user.sendEmailVerification()
            isEmailVerified = result.user.isEmailVerified
        } catch {
            errorMessage = Self.friendlyMessage(error)
        }
        isLoading = false
    }

    /// Перечитывает пользователя с сервера — так можно узнать, что ссылку в письме
    /// уже открыли (Firebase не сообщает об этом сам по себе).
    func reloadEmailVerificationStatus() async {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await user.reload()
            isEmailVerified = user.isEmailVerified
            statusMessage = isEmailVerified ? nil : "Почта пока не подтверждена — проверь письмо (и папку «Спам»)."
        } catch {
            errorMessage = Self.friendlyMessage(error)
        }
        isLoading = false
    }

    func resendVerificationEmail() async {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        do {
            try await user.sendEmailVerification()
            statusMessage = "Письмо отправлено ещё раз — проверь почту."
        } catch {
            errorMessage = Self.friendlyMessage(error)
        }
        isLoading = false
    }

    func signInWithGoogle() {
        guard !isLoading else { return }
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Не найден clientID Firebase. Проверь, что GoogleService-Info.plist добавлен в проект."
            return
        }
        guard let presentingViewController = Self.topViewController() else {
            errorMessage = "Не удалось открыть окно для входа через Google."
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        isLoading = true

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.isLoading = false
                    self.errorMessage = Self.friendlyMessage(error)
                    return
                }
                guard let googleUser = result?.user, let idToken = googleUser.idToken?.tokenString else {
                    self.isLoading = false
                    self.errorMessage = "Google не вернул токен входа."
                    return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: googleUser.accessToken.tokenString
                )
                Auth.auth().signIn(with: credential) { authResult, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if let error {
                            self.errorMessage = Self.friendlyMessage(error)
                        } else {
                            // Google уже подтвердил почту пользователя, доп. письмо не нужно.
                            self.isEmailVerified = authResult?.user.isEmailVerified ?? true
                        }
                    }
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            statusMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = Self.friendlyMessage(error)
        }
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private static func friendlyMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .wrongPassword, .invalidCredential:
                return "Неверный email или пароль."
            case .emailAlreadyInUse:
                return "Этот email уже зарегистрирован — попробуй войти."
            case .invalidEmail:
                return "Некорректный email."
            case .weakPassword:
                return "Пароль слишком простой — минимум 6 символов."
            case .userNotFound:
                return "Пользователь с таким email не найден."
            case .networkError:
                return "Нет соединения с интернетом."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
