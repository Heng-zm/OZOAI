import Foundation
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var successText: String?
    @State private var showServerConfig = false
    @State private var showSignOutConfirmation = false

    private enum AuthMode: String, CaseIterable, Identifiable {
        case signIn
        case signUp

        var id: String { rawValue }

        var title: String {
            switch self {
            case .signIn: return "Sign in"
            case .signUp: return "Create account"
            }
        }

        var headline: String {
            switch self {
            case .signIn: return "Welcome back."
            case .signUp: return "Make OZO yours."
            }
        }

        var subheadline: String {
            switch self {
            case .signIn: return "Sign in to keep your account in one place."
            case .signUp: return "Use email, Google, or your Apple ID."
            }
        }

        var submitTitle: String {
            switch self {
            case .signIn: return "Sign in"
            case .signUp: return "Create account"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if auth.isSignedIn {
                        signedInContent
                    } else {
                        signInContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(background.ignoresSafeArea())
            .navigationTitle(auth.isSignedIn ? "Account" : "OZO account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .sheet(isPresented: $showServerConfig) {
                AuthServerView()
                    .environmentObject(auth)
            }
            .confirmationDialog(
                "Sign out of OZO?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    Task { await signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your chats stay on this iPhone. You can sign in again anytime.")
            }
            .onChange(of: mode) { _, _ in
                errorText = nil
                successText = nil
                showPassword = false
            }
            .task {
                await auth.refreshOAuthProviders()
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    // MARK: - Signed in

    private var signedInContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(OZOTheme.brandGradient)
                        .frame(width: 76, height: 76)

                    Text(auth.initials)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: OZOTheme.accent.opacity(0.28), radius: 18, y: 8)

                VStack(spacing: 4) {
                    Text(auth.accountName)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .tracking(-0.4)

                    Text(auth.accountEmail)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack(spacing: 5) {
                    Circle()
                        .fill(OZOTheme.positive)
                        .frame(width: 5, height: 5)
                    Text("Signed in")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(OZOTheme.positive)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(OZOTheme.positive.opacity(0.10), in: Capsule())
            }
            .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 13) {
                accountRow(
                    icon: "checkmark.shield.fill",
                    tint: OZOTheme.positive,
                    title: "Account connected",
                    detail: "Your sign-in is stored securely in the iPhone Keychain."
                )

                Divider().opacity(0.55)

                accountRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    tint: OZOTheme.accent,
                    title: "Chats stay local",
                    detail: "Signing in doesn't upload your conversations."
                )

                Divider().opacity(0.55)

                Button {
                    showServerConfig = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Account server")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(.primary)
                            Text(auth.config.host)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(15)
            .ozoCard(cornerRadius: 20)

            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("Sign out")
                        .font(.system(size: 13.5, weight: .semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(OZOPressStyle())

            Text("Signing out won't delete your chats or API keys.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func accountRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Signed out

    private var signInContent: some View {
        VStack(spacing: 18) {
            header
            if !auth.config.isConfigured {
                serverBanner
            }
            modePicker
            formCard
            socialCard
            privacyNote
            serverFooter
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(OZOTheme.accent.opacity(0.12))
                    .frame(width: 76, height: 76)
                    .blur(radius: 2)

                OZOLogo(size: 58)
            }

            VStack(spacing: 4) {
                Text(mode.headline)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.6)

                Text(mode.subheadline)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private var serverBanner: some View {
        Button {
            showServerConfig = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Account server not set up")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Add your Supabase project URL and publishable key to enable sign in.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Text("Set up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .padding(12)
            .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.orange.opacity(0.16), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var modePicker: some View {
        HStack(spacing: 3) {
            ForEach(AuthMode.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        mode = item
                    }
                    Haptics.tap(settings.hapticsEnabled)
                } label: {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(mode == item ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            mode == item ? OZOTheme.surface : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .shadow(
                            color: mode == item ? .black.opacity(0.05) : .clear,
                            radius: 6,
                            y: 2
                        )
                }
                .buttonStyle(.plain)
                .accessibilityValue(mode == item ? "Selected" : "Not selected")
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var formCard: some View {
        VStack(spacing: 13) {
            fieldLabel("Email")
            HStack(spacing: 9) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 17)

                TextField("you@example.com", text: $email)
                    .font(.system(size: 14))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .submitLabel(.next)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )

            fieldLabel(mode == .signIn ? "Password" : "Create a password")
            HStack(spacing: 9) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 17)

                Group {
                    if showPassword {
                        TextField("At least 8 characters", text: $password)
                    } else {
                        SecureField("At least 8 characters", text: $password)
                    }
                }
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(mode == .signIn ? .password : .newPassword)
                .submitLabel(mode == .signIn ? .go : .next)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )

            if mode == .signUp {
                fieldLabel("Confirm password")
                HStack(spacing: 9) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(width: 17)
                    SecureField("Type it again", text: $confirmPassword)
                        .font(.system(size: 14))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.newPassword)
                        .submitLabel(.go)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 11)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
                )
            }

            if let message = successText {
                feedbackBanner(message, tint: OZOTheme.positive, icon: "checkmark.circle.fill")
            }

            if let errorText {
                feedbackBanner(errorText, tint: .orange, icon: "exclamationmark.circle.fill")
            }

            Button {
                submit()
            } label: {
                HStack(spacing: 7) {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(isWorking ? "Please wait…" : mode.submitTitle)
                        .font(.system(size: 14.5, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    OZOTheme.brandGradient,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: OZOTheme.accent.opacity(isWorking ? 0 : 0.22), radius: 12, y: 5)
            }
            .buttonStyle(OZOPressStyle())
            .disabled(isWorking)

            Text(mode == .signIn
                 ? "Email and password are handled by your account server."
                 : "Use 8 or more characters. You can add Google or Apple next time.")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .ozoCard(cornerRadius: 20, shadow: true)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feedbackBanner(_ message: String, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 0.7)
        )
    }

    private var socialCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(OZOTheme.hairline)
                    .frame(height: 0.7)
                Text("OR CONTINUE WITH")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                    .fixedSize()
                Rectangle()
                    .fill(OZOTheme.hairline)
                    .frame(height: 0.7)
            }

            HStack(spacing: 9) {
                socialButton(
                    title: "Google",
                    symbol: nil,
                    leading: AnyView(
                        Text("G")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x4285F4))
                    )
                ) {
                    startOAuth(.google)
                }

                socialButton(
                    title: "Apple",
                    symbol: "apple.logo",
                    leading: nil
                ) {
                    startOAuth(.apple)
                }
            }

            Text("Apple sign-in uses your Apple ID or iCloud account. Google opens a secure sign-in page.")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let oauthSetupNote {
                Text(oauthSetupNote)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(15)
        .ozoCard(cornerRadius: 20)
    }

    private var oauthSetupNote: String? {
        guard auth.oauthSettingsLoaded else { return nil }
        let disabled = SupabaseOAuthProvider.allCases.filter {
            !auth.enabledOAuthProviders.contains($0)
        }
        guard !disabled.isEmpty else { return nil }

        let names = disabled.map(\.title).joined(separator: " and ")
        let verb = disabled.count == 1 ? "isn't" : "aren't"
        let pronoun = disabled.count == 1 ? "it" : "them"
        return "\(names) sign-in \(verb) enabled on this account server yet. Enable \(pronoun) in Supabase → Authentication → Providers."
    }

    private func socialButton(
        title: String,
        symbol: String?,
        leading: AnyView?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let leading {
                    leading
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(OZOPressStyle())
        .disabled(isWorking)
    }

    private var privacyNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.shield.fill")
            Text("Optional account. Chat without one; your API keys and chats stay on this iPhone.")
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }

    private var serverFooter: some View {
        HStack(spacing: 4) {
            if auth.config.isConfigured {
                Text("Connected to \(auth.config.host)")
            } else {
                Text("No account server configured")
            }
            Text("·")
            Button("Server settings") {
                showServerConfig = true
            }
            .fontWeight(.semibold)
            .foregroundStyle(OZOTheme.accent)
        }
        .font(.system(size: 9.5))
        .foregroundStyle(.tertiary)
    }

    private var background: some View {
        ZStack {
            OZOTheme.groupedBackground

            RadialGradient(
                colors: [OZOTheme.accent.opacity(0.09), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 430
            )

            RadialGradient(
                colors: [OZOTheme.violet.opacity(0.06), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 470
            )
        }
    }

    // MARK: - Actions

    private func submit() {
        errorText = nil
        successText = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorText = "Enter a valid email address."
            return
        }
        guard !password.isEmpty else {
            errorText = "Enter your password."
            return
        }
        if mode == .signUp {
            guard password.count >= 8 else {
                errorText = "Use at least 8 characters for your password."
                return
            }
            guard password == confirmPassword else {
                errorText = "The passwords don't match."
                return
            }
        }
        guard auth.config.isConfigured else {
            errorText = "Set up your account server first."
            showServerConfig = true
            return
        }

        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                switch mode {
                case .signIn:
                    try await auth.signIn(email: trimmedEmail, password: password)
                    Haptics.success(settings.hapticsEnabled)
                    dismiss()
                case .signUp:
                    let result = try await auth.signUp(email: trimmedEmail, password: password)
                    switch result {
                    case .signedIn:
                        Haptics.success(settings.hapticsEnabled)
                        dismiss()
                    case .confirmationRequired:
                        successText = "Check your email and open the confirmation link on this iPhone. It can return you to OZO AI, or you can sign in after confirming."
                        Haptics.success(settings.hapticsEnabled)
                    }
                }
            } catch let error as AuthError {
                if error != .cancelled {
                    errorText = error.localizedDescription
                    Haptics.error(settings.hapticsEnabled)
                }
            } catch {
                errorText = error.localizedDescription
                Haptics.error(settings.hapticsEnabled)
            }
        }
    }

    private func startOAuth(_ provider: SupabaseOAuthProvider) {
        errorText = nil
        successText = nil

        guard auth.config.isConfigured else {
            errorText = "Set up your account server first."
            showServerConfig = true
            return
        }

        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await auth.signInWithOAuth(provider)
                Haptics.success(settings.hapticsEnabled)
                dismiss()
            } catch let error as AuthError {
                if error != .cancelled {
                    errorText = error.localizedDescription
                    Haptics.error(settings.hapticsEnabled)
                }
            } catch {
                errorText = error.localizedDescription
                Haptics.error(settings.hapticsEnabled)
            }
        }
    }

    private func signOut() async {
        await auth.signOut()
        Haptics.success(settings.hapticsEnabled)
        dismiss()
    }
}
