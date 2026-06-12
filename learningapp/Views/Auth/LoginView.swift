import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showReset = false

    private let cream = Color(red: 1, green: 0.961, blue: 0.914)

    var body: some View {
        NavigationStack {
            ZStack {
                cream.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color("Darkgreen").opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(0.8)
                        Text("Sign in")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color("Darkgreen"))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)

                    HStack {
                        Spacer()
                        Image("clear_happy_giraffe")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .padding(.trailing, 20)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 12) {
                            AuthField(placeholder: "Email address", text: $email, isEmail: true)
                            AuthField(placeholder: "Password", text: $password, isSecure: true)
                        }

                        if let err = auth.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            showReset = true
                        } label: {
                            Text("Forgot your password?")
                                .font(.caption)
                                .foregroundStyle(cream.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        AuthPrimaryButton(label: "Sign in", isLoading: auth.isLoading) {
                            Task { await auth.signIn(email: email, password: password) }
                        }
                        .disabled(email.isEmpty || password.isEmpty)

                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(cream.opacity(0.75))
                            Button("Sign up") { showSignUp = true }
                                .foregroundStyle(cream)
                                .fontWeight(.semibold)
                        }
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 36,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 36,
                            style: .continuous
                        )
                        .fill(Color("Darkgreen"))
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .alert("Reset password", isPresented: $showReset) {
                TextField("Email address", text: $email)
                Button("Send") { Task { await auth.resetPassword(email: email) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your email and we'll send you a link.")
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Sign Up

struct SignUpView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordMismatch = false

    private let cream = Color(red: 1, green: 0.961, blue: 0.914)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color("Darkgreen"))
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Create your account")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color("Darkgreen").opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text("Sign up")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color("Darkgreen"))
                }
                .padding(.horizontal, 28)
                .padding(.top, 10)

                HStack {
                    Spacer()
                    Image("normal_giraffe")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 160)
                        .padding(.trailing, 20)
                }

                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 12) {
                        AuthField(placeholder: "Email address", text: $email, isEmail: true)
                        AuthField(placeholder: "Password", text: $password, isSecure: true)
                        AuthField(placeholder: "Confirm password", text: $confirmPassword, isSecure: true)
                    }

                    if passwordMismatch {
                        Text("Passwords don't match.")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    AuthPrimaryButton(label: "Create account", isLoading: auth.isLoading) {
                        guard password == confirmPassword else { passwordMismatch = true; return }
                        passwordMismatch = false
                        Task { await auth.signUp(email: email, password: password) }
                    }
                    .disabled(email.isEmpty || password.isEmpty || confirmPassword.isEmpty)

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(cream.opacity(0.75))
                        Button("Sign in") { dismiss() }
                            .foregroundStyle(cream)
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 36,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 36,
                        style: .continuous
                    )
                    .fill(Color("Darkgreen"))
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Shared components

private struct AuthField: View {
    let placeholder: String
    @Binding var text: String
    var isEmail: Bool = false
    var isSecure: Bool = false

    private let cream = Color(red: 1, green: 0.961, blue: 0.914)

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .autocapitalization(.none)
                    .keyboardType(isEmail ? .emailAddress : .default)
                    #endif
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(cream, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.black)
    }
}

private struct AuthPrimaryButton: View {
    let label: String
    let isLoading: Bool
    let action: () -> Void

    private let cream = Color(red: 1, green: 0.961, blue: 0.914)

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(Color("Darkgreen"))
                } else {
                    Text(label).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Color("Darkgreen"))
            .background(cream, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading)
    }
}

#Preview {
    LoginView()
        .environment(AuthService())
}
