import Foundation
import FirebaseAuth

@MainActor
@Observable
final class AuthService {
    var currentUser: FirebaseAuth.User? = nil
    var isLoading = false
    var errorMessage: String? = nil
    var needsOnboarding = false

    private var stateHandle: AuthStateDidChangeListenerHandle?

    init() {
        currentUser = Auth.auth().currentUser
        stateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    var isAuthenticated: Bool { currentUser != nil }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = result.user
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            currentUser = result.user
            needsOnboarding = true
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func completeOnboarding() {
        needsOnboarding = false
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signOut() {
        try? Auth.auth().signOut()
        currentUser = nil
    }

    // MARK: - Helpers

    private func friendlyError(_ error: Error) -> String {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidEmail:      return "El correo no es válido."
        case .emailAlreadyInUse: return "Ese correo ya está registrado."
        case .weakPassword:      return "La contraseña debe tener al menos 6 caracteres."
        case .wrongPassword:     return "Contraseña incorrecta."
        case .userNotFound:      return "No existe cuenta con ese correo."
        case .networkError:      return "Sin conexión a internet."
        default:                 return error.localizedDescription
        }
    }
}
