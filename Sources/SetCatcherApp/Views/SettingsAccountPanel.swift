import ClerkKit
import ClerkKitUI
import SwiftUI

/// Optional Clerk account controls for Settings. Local protection never depends on sign-in.
struct SettingsAccountPanel: View {
    @EnvironmentObject private var model: AppModel
    let isAccountAuthEnabled: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        Panel(title: "Account", padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Local protection never depends on an account.")
                    .font(.system(size: DJToken.TypeSize.body, weight: .medium))
                Text("Audio files are never uploaded by default.")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                Text("Full tracklists stay on this Mac unless you explicitly export them.")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)
                Text("Diagnostics exports contain metadata only — paths, timings, counts, and error strings.")
                    .font(.system(size: DJToken.TypeSize.body))
                    .foregroundStyle(DJToken.mutedForeground)

                if isAccountAuthEnabled {
                    SettingsAccountAuthControls()
                        .padding(.top, 6)
                } else {
                    Text("Account sign-in is not configured for this build. Local protection, archive, scan, import, and diagnostics still work offline.")
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(DJToken.mutedForeground)
                        .accessibilityLabel("Account sign-in is not configured for this build. Local protection, archive, scan, import, and diagnostics still work offline.")
                        .accessibilityIdentifier("settings.accountOffline")
                }

                Button {
                    model.showOnboardingAgain()
                } label: {
                    Label("Show First-Run Setup", systemImage: "sparkles.rectangle.stack")
                }
                .buttonStyle(DJSecondaryButtonStyle())
                .accessibilityIdentifier("settings.showOnboarding")

                Button {
                    if let url = URL(string: AccountAPIClient.baseURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open Account in Browser", systemImage: "person.crop.circle")
                }
                .buttonStyle(DJGhostButtonStyle())
                .accessibilityIdentifier("settings.openAccount")
            }
        }
    }
}

private struct SettingsAccountAuthControls: View {
    @EnvironmentObject private var model: AppModel
    @Environment(Clerk.self) private var clerk
    @State private var authIsPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            UserButton(signedOutContent: {
                Button {
                    authIsPresented = true
                } label: {
                    Label("Sign in", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(DJSecondaryButtonStyle())
                .accessibilityIdentifier("settings.signIn")
            })

            if clerk.user != nil {
                if let summary = model.accountLicenseSummary {
                    KeyValueRow(key: "License", value: summary)
                        .accessibilityIdentifier("settings.accountLicense")
                }
                if let message = model.accountSyncMessage {
                    Text(message)
                        .font(.system(size: DJToken.TypeSize.body))
                        .foregroundStyle(DJToken.mutedForeground)
                        .accessibilityIdentifier("settings.accountSyncMessage")
                }

                Button {
                    Task { await syncAccount() }
                } label: {
                    Label(
                        model.isAccountSyncing ? "Syncing…" : "Refresh Account",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(DJSecondaryButtonStyle())
                .disabled(model.isAccountSyncing)
                .accessibilityIdentifier("settings.refreshAccount")

                Button {
                    Task { await uploadDiagnostics() }
                } label: {
                    Label("Upload Diagnostics Metadata", systemImage: "arrow.up.doc")
                }
                .buttonStyle(DJGhostButtonStyle())
                .disabled(model.isAccountSyncing)
                .accessibilityIdentifier("settings.uploadDiagnostics")
            }
        }
        .sheet(isPresented: $authIsPresented) {
            AuthView()
        }
        .onChange(of: clerk.user?.id) { _, userID in
            if userID != nil {
                authIsPresented = false
                Task { await syncAccount() }
            } else {
                model.clearAccountSessionState()
            }
        }
        .task(id: clerk.user?.id) {
            if clerk.user != nil {
                await syncAccount()
            }
        }
    }

    private func syncAccount() async {
        do {
            let token = try await clerk.session?.getToken()
            await model.syncAccountSession(bearerToken: token)
        } catch {
            await model.syncAccountSession(bearerToken: nil)
            model.statusMessage = "Could not read account session: \(error.localizedDescription)"
        }
    }

    private func uploadDiagnostics() async {
        do {
            guard let token = try await clerk.session?.getToken() else {
                model.statusMessage = "Sign in again to upload diagnostics metadata."
                return
            }
            await model.uploadDiagnosticsToAccount(bearerToken: token)
        } catch {
            model.statusMessage = "Could not upload diagnostics: \(error.localizedDescription)"
        }
    }
}

#Preview("Signed out") {
    SettingsAccountPanel(isAccountAuthEnabled: true)
        .environmentObject(AppModel())
        .environment(Clerk.preview { preview in
            preview.isSignedIn = false
        })
        .padding()
        .frame(width: 420)
}

#Preview("Signed in") {
    SettingsAccountPanel(isAccountAuthEnabled: true)
        .environmentObject(AppModel())
        .environment(Clerk.preview())
        .padding()
        .frame(width: 420)
}

#Preview("Offline") {
    SettingsAccountPanel(isAccountAuthEnabled: false)
        .environmentObject(AppModel())
        .padding()
        .frame(width: 420)
}
