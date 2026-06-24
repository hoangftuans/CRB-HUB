//
//  ContentView.swift
//  CRB Hub
//
//  Created by Nguyễn Hoàng Tuấn on 23/6/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var privacyShieldVisible = false
    @State private var unlockPassword = ""
    @State private var isUnlocking = false

    var body: some View {
        ZStack {
            if appState.hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView()
            }

            if privacyShieldVisible {
                privacyShield
            }

            if appState.isAppLocked {
                appLockView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.2), value: appState.isAppLocked)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                privacyShieldVisible = false
                appState.handleAppActive()
            case .inactive:
                privacyShieldVisible = true
            case .background:
                privacyShieldVisible = true
                appState.markBackgrounded()
                appState.clearP2PSession()
            @unknown default:
                privacyShieldVisible = true
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Wallet".localized, systemImage: "wallet.bifold", value: 0) {
                WalletHomeView()
            }

            Tab("Mining".localized, systemImage: "hammer.fill", value: 1) {
                MiningDashboardView()
            }

            Tab("P2P".localized, systemImage: "arrow.left.arrow.right", value: 2) {
                P2PMarketView()
            }

            Tab("Settings".localized, systemImage: "gearshape.fill", value: 3) {
                SettingsView()
            }
        }
        .tint(CRBTheme.Colors.cyan)
    }

    private var privacyShield: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: CRBTheme.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.cyan)

                Text("CRB Hub")
                    .font(CRBTheme.Typography.title())
                    .foregroundColor(CRBTheme.Colors.ink)
            }
        }
    }

    private var appLockView: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: CRBTheme.Spacing.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.cyan)

                VStack(spacing: CRBTheme.Spacing.xs) {
                    Text("CRB Hub Locked".localized)
                        .font(CRBTheme.Typography.title())
                        .foregroundColor(CRBTheme.Colors.ink)
                    Text("Unlock to view wallet balances, history, and settings.".localized)
                        .font(CRBTheme.Typography.body())
                        .foregroundColor(CRBTheme.Colors.muted)
                        .multilineTextAlignment(.center)
                }

                GradientButton(
                    title: isUnlocking ? "Unlocking...".localized : "Unlock with Face ID".localized,
                    icon: "faceid",
                    isDisabled: isUnlocking
                ) {
                    Task {
                        isUnlocking = true
                        await appState.unlockAppWithBiometrics()
                        isUnlocking = false
                    }
                }

                if WalletSecurityStore.shared.isPasswordEnabled {
                    SecureField("Wallet Password".localized, text: $unlockPassword)
                        .textFieldStyle(.plain)
                        .foregroundColor(CRBTheme.Colors.ink)
                        .padding(CRBTheme.Spacing.md)
                        .background(CRBTheme.Colors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))

                    Button {
                        appState.unlockApp(password: unlockPassword)
                        if !appState.isAppLocked {
                            unlockPassword = ""
                        }
                    } label: {
                        Text("Unlock with Password".localized)
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CRBTheme.Colors.violet.opacity(0.14))
                            .foregroundColor(CRBTheme.Colors.violet)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                    }
                    .disabled(unlockPassword.isEmpty)
                }

                if let error = appState.appLockError {
                    Text(error)
                        .font(CRBTheme.Typography.caption())
                        .foregroundColor(CRBTheme.Colors.error)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(CRBTheme.Spacing.xl)
            .frame(maxWidth: 420)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
