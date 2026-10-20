import Foundation
import SwiftUI

struct AuthServerView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var projectURL = ""
    @State private var anonKey = ""
    @State private var showKey = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var successText: String?
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    setupCard
                    instructionsCard
                    dangerZone
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(background.ignoresSafeArea())
            .navigationTitle("Account server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .onAppear {
                if projectURL.isEmpty {
                    projectURL = auth.config.projectURL
                    anonKey = auth.config.anonKey
                }
            }
            .confirmationDialog(
                "Clear account server?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear and sign out", role: .destructive) {
                    auth.clearConfiguration()
                    Haptics.success(true)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to enter the project URL and publishable key again.")
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    private var header: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(OZOTheme.accent.opacity(0.12))
                    .frame(width: 66, height: 66)

                Image(systemName: "server.rack")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(OZOTheme.accent)
            }

            VStack(spacing: 3) {
                Text("Connect your account server")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .tracking(-0.4)

                Text("OZO uses Supabase for email, Google, and Apple sign-in.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            fieldLabel("Project URL")
            HStack(spacing: 9) {
                Image(systemName: "link")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 17)
                TextField("https://your-project.supabase.co", text: $projectURL)
                    .font(.system(size: 13, design: .monospaced))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )

            fieldLabel("Publishable / anon key")
            HStack(spacing: 9) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 17)

                Group {
                    if showKey {
                        TextField("sb_publishable_…", text: $anonKey)
                    } else {
                        SecureField("sb_publishable_…", text: $anonKey)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showKey ? "Hide publishable key" : "Show publishable key")
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )

            if let successText {
                feedback(successText, tint: OZOTheme.positive, icon: "checkmark.circle.fill")
            }
            if let errorText {
                feedback(errorText, tint: .orange, icon: "exclamationmark.circle.fill")
            }

            Button {
                save()
            } label: {
                HStack(spacing: 7) {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(isWorking ? "Testing connection…" : "Save & test")
                        .font(.system(size: 14, weight: .semibold))
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

            Text("Use the public anon/publishable key, never the service_role key.")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(15)
        .ozoCard(cornerRadius: 20, shadow: true)
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUPABASE SETUP")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.tertiary)

            instructionRow(
                number: "1",
                title: "Add the redirect URL",
                detail: "Authentication → URL Configuration → add ozoai://auth-callback"
            )
            instructionRow(
                number: "2",
                title: "Email confirmation",
                detail: "Authentication → Providers → Email. Confirm email is on by default; turn it off only while testing."
            )
            instructionRow(
                number: "3",
                title: "Enable providers",
                detail: "Authentication → Providers → turn on Google and Apple."
            )
            instructionRow(
                number: "4",
                title: "Add provider credentials",
                detail: "Google needs a Google Cloud OAuth client. Apple needs an Apple Developer account and Services ID."
            )

            Link(destination: URL(string: "https://supabase.com/dashboard")!) {
                HStack(spacing: 3) {
                    Text("Open Supabase dashboard")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 7.5, weight: .bold))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OZOTheme.accent)
            }
            .padding(.top, 1)
        }
        .padding(15)
        .ozoCard(cornerRadius: 20)
    }

    private func instructionRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(OZOTheme.accent)
                .frame(width: 20, height: 20)
                .background(OZOTheme.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var dangerZone: some View {
        if auth.config.isConfigured {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Clear account server")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(.red.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(.red.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(OZOPressStyle())
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feedback(_ message: String, tint: Color, icon: String) -> some View {
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

    private var background: some View {
        ZStack {
            OZOTheme.groupedBackground

            RadialGradient(
                colors: [OZOTheme.accent.opacity(0.07), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
        }
    }

    private func save() {
        errorText = nil
        successText = nil

        let url = projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !key.isEmpty else {
            errorText = "Enter both the project URL and publishable key."
            return
        }
        guard !key.lowercased().contains("service_role") else {
            errorText = "That looks like a service_role key. Use the public anon/publishable key instead."
            return
        }

        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await auth.configure(projectURL: url, anonKey: key)
                successText = "Connected. You can now sign in with email, Google, or Apple."
                Haptics.success(true)
                try? await Task.sleep(nanoseconds: 650_000_000)
                dismiss()
            } catch let error as AuthError {
                errorText = error.localizedDescription
                Haptics.error(true)
            } catch {
                errorText = error.localizedDescription
                Haptics.error(true)
            }
        }
    }
}
