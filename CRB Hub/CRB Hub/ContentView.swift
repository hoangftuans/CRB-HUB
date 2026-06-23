//
//  ContentView.swift
//  CRB Hub
//
//  Created by Nguyễn Hoàng Tuấn on 23/6/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
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
}

#Preview {
    ContentView()
        .environment(AppState())
}
