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
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                privacyShieldVisible = false
            case .inactive:
                privacyShieldVisible = true
            case .background:
                privacyShieldVisible = true
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
}

#Preview {
    ContentView()
        .environment(AppState())
}
