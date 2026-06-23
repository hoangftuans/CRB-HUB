import SwiftUI

struct MiningSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedRegion: MiningRegion = .europe
    @State private var isSolo = false
    @State private var workerName = "rig1"
    @State private var copiedCommand = false
    
    enum MiningRegion: String, CaseIterable, Identifiable {
        case europe = "Europe"
        case russia = "Russia"
        case usa = "USA"
        case asia = "Asia"
        
        var id: String { rawValue }
        
        var host: String {
            switch self {
            case .europe: return "stratum.cereblix.com"
            case .russia: return "ru.cereblix.com"
            case .usa: return "us.cereblix.com"
            case .asia: return "asia.cereblix.com"
            }
        }
        
        var flag: String {
            switch self {
            case .europe: return "🇩🇪"
            case .russia: return "🇷🇺"
            case .usa: return "🇺🇸"
            case .asia: return "🇸🇬"
            }
        }
        
        var location: String {
            switch self {
            case .europe: return "Germany (Recommended)"
            case .russia: return "Moscow"
            case .usa: return "New York"
            case .asia: return "Singapore"
            }
        }
    }
    
    var port: Int {
        isSolo ? 3334 : 3333
    }
    
    var minerCommand: String {
        let addr = appState.selectedWallet?.address ?? "crb1YOURADDRESS"
        return "unm -o \(selectedRegion.host):\(port) -u \(addr).\(workerName)"
    }
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: CRBTheme.Spacing.xl) {
                    // Header
                    VStack(spacing: CRBTheme.Spacing.sm) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(CRBTheme.Gradients.primary)
                        
                        Text("Setup Miner".localized)
                            .font(CRBTheme.Typography.title())
                            .foregroundColor(CRBTheme.Colors.ink)
                        
                        Text("Configure your miner to start earning CRB".localized)
                            .font(CRBTheme.Typography.body())
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                    .padding(.top, CRBTheme.Spacing.md)
                    
                    // Region picker
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                        SectionHeader(title: "Choose Region".localized, icon: "globe")
                        
                        ForEach(MiningRegion.allCases) { region in
                            Button {
                                withAnimation { selectedRegion = region }
                            } label: {
                                HStack(spacing: CRBTheme.Spacing.md) {
                                    Text(region.flag)
                                        .font(.system(size: 24))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(region.rawValue)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(CRBTheme.Colors.ink)
                                        Text(region.location)
                                            .font(.system(size: 12))
                                            .foregroundColor(CRBTheme.Colors.muted)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedRegion == region {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(CRBTheme.Colors.cyan)
                                    }
                                }
                                .padding(CRBTheme.Spacing.md)
                                .background(selectedRegion == region ? CRBTheme.Colors.cyan.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.sm))
                            }
                        }
                    }
                    .glassCard()
                    
                    // Pool vs Solo
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                        SectionHeader(title: "Pool Type".localized, icon: "person.2.fill")
                        
                        HStack(spacing: CRBTheme.Spacing.md) {
                            modeButton(title: "Pool".localized, subtitle: "Steady payouts".localized, icon: "person.2.fill", selected: !isSolo) {
                                withAnimation { isSolo = false }
                            }
                            
                            modeButton(title: "Solo".localized, subtitle: "Full block reward".localized, icon: "person.fill", selected: isSolo) {
                                withAnimation { isSolo = true }
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text(isSolo ? "Solo: You keep the whole 50 CRB block reward (lottery)".localized : "Pool: Port 3333, fee 1%, auto payout when threshold reached".localized)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(CRBTheme.Colors.muted)
                    }
                    .glassCard()
                    
                    // Worker name
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                        Text("Worker Name (optional)".localized)
                            .font(CRBTheme.Typography.caption())
                            .foregroundColor(CRBTheme.Colors.muted)
                        
                        TextField("rig1", text: $workerName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.ink)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(CRBTheme.Spacing.md)
                            .background(CRBTheme.Colors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                                    .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
                            )
                    }
                    .glassCard()
                    
                    // Command output
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                        SectionHeader(title: "Miner Command".localized, icon: "terminal.fill")
                        
                        Text(minerCommand)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.cyan)
                            .textSelection(.enabled)
                            .padding(CRBTheme.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CRBTheme.Colors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                        
                        GradientButton(
                            title: copiedCommand ? "Copied!".localized : "Copy Command".localized,
                            icon: copiedCommand ? "checkmark" : "doc.on.doc"
                        ) {
                            UIPasteboard.general.string = minerCommand
                            withAnimation {
                                copiedCommand = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copiedCommand = false }
                            }
                        }
                    }
                    .glassCard()
                    
                    // Compatible miners
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.md) {
                        SectionHeader(title: "Compatible Miners".localized, icon: "cpu")
                        
                        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                            minerInfo("UNM", "Recommended, highest hashrate")
                            minerInfo("SRBMiner", "Stratum compatible")
                            minerInfo("XMRig", "xmrig-cereblix fork")
                            minerInfo("cereblix-miner", "Native HTTP getwork (legacy)")
                        }
                    }
                    .glassCard()
                    
                    // Notes
                    VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
                        SectionHeader(title: "Notes".localized, icon: "info.circle")
                        
                        noteItem("Pool fee: 1%".localized)
                        noteItem("Auto payout when threshold reached".localized)
                        noteItem("NeuroMorph PoW algorithm (CPU-only)".localized)
                        noteItem("Use the same address for mining and wallet".localized)
                        noteItem("Epochs change every 4096 blocks".localized)
                    }
                    .glassCard()
                }
                .padding(CRBTheme.Spacing.xl)
            }
        }
        .navigationTitle("Setup Miner".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func modeButton(title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CRBTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(selected ? CRBTheme.Colors.cyan : CRBTheme.Colors.muted)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(selected ? CRBTheme.Colors.ink : CRBTheme.Colors.muted)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(CRBTheme.Colors.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(CRBTheme.Spacing.lg)
            .background(selected ? CRBTheme.Colors.cyan.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                    .stroke(selected ? CRBTheme.Colors.cyan.opacity(0.3) : CRBTheme.Colors.cardBorder, lineWidth: 1)
            )
        }
    }
    
    private func minerInfo(_ name: String, _ desc: String) -> some View {
        HStack(spacing: CRBTheme.Spacing.sm) {
            Circle()
                .fill(CRBTheme.Colors.cyan)
                .frame(width: 4, height: 4)
            
            Text(name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CRBTheme.Colors.ink)
            
            Text("— \(desc)")
                .font(.system(size: 12))
                .foregroundColor(CRBTheme.Colors.muted)
        }
    }
    
    private func noteItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CRBTheme.Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(CRBTheme.Colors.buyGreen)
                .padding(.top, 3)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(CRBTheme.Colors.muted)
        }
    }
}

#Preview {
    NavigationStack {
        MiningSetupView()
            .environment(AppState())
    }
}
