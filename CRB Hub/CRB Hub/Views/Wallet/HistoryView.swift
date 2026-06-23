import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = WalletViewModel()
    
    var body: some View {
        ZStack {
            CRBTheme.Colors.background.ignoresSafeArea()
            
            if viewModel.transactions.isEmpty && !viewModel.isLoadingHistory {
                EmptyStateView(
                    icon: "tray",
                    title: "No history found".localized,
                    message: "Your transaction history will appear here".localized
                )
            } else {
                List {
                    ForEach(viewModel.transactions) { tx in
                        transactionRow(tx)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onAppear {
                                // Infinite scroll
                                if tx.id == viewModel.transactions.last?.id && viewModel.hasMoreHistory {
                                    Task {
                                        if let addr = appState.selectedWallet?.address {
                                            await viewModel.loadHistory(address: addr)
                                        }
                                    }
                                }
                            }
                    }
                    
                    if viewModel.isLoadingHistory {
                        HStack {
                            Spacer()
                            LoadingView(message: "Loading...".localized)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    if let addr = appState.selectedWallet?.address {
                        await viewModel.loadHistory(address: addr, refresh: true)
                    }
                }
            }
        }
        .navigationTitle("Transaction History".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let addr = appState.selectedWallet?.address {
                await viewModel.loadHistory(address: addr, refresh: true)
            }
        }
    }
    
    private func transactionRow(_ tx: CRBTransaction) -> some View {
        let type = tx.transactionType(for: appState.selectedWallet?.address ?? "")
        
        return VStack(spacing: 0) {
            HStack(spacing: CRBTheme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(typeColor(type).opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(typeColor(type))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(type.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(CRBTheme.Colors.ink)
                        
                        if let height = tx.height {
                            PillBadge(text: "#\(height)", color: CRBTheme.Colors.muted)
                        }
                    }
                    
                    // Address
                    if type == .sent, let to = tx.to {
                        Text("→ \(AddressValidator.truncatedAddress(to, leading: 8, trailing: 6))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.muted)
                    } else if type == .received, let from = tx.from {
                        Text("← \(AddressValidator.truncatedAddress(from, leading: 8, trailing: 6))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CRBTheme.Colors.muted)
                    }
                    
                    if let time = tx.time {
                        Text(CRBUnits.formatDate(time))
                            .font(.system(size: 11))
                            .foregroundColor(CRBTheme.Colors.muted.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(type == .sent ? "-" : "+")\(CRBUnits.formatCRBCompact(tx.amount)) CRB")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(type == .sent ? CRBTheme.Colors.sellRed : CRBTheme.Colors.buyGreen)
                    
                    FiatValueView(baseUnits: tx.amount, font: .system(size: 11))
                    
                    if tx.fee > 0 {
                        Text("Fee:".localized + " \(CRBUnits.formatCRBCompact(tx.fee))")
                            .font(.system(size: 9))
                            .foregroundColor(CRBTheme.Colors.muted.opacity(0.6))
                    }
                }
            }
            .padding(CRBTheme.Spacing.lg)
            .background(CRBTheme.Gradients.card)
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                    .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, CRBTheme.Spacing.sm)
        .padding(.vertical, CRBTheme.Spacing.xs)
    }
    
    private func typeColor(_ type: CRBTransaction.TransactionType) -> Color {
        switch type {
        case .sent: return CRBTheme.Colors.sellRed
        case .received: return CRBTheme.Colors.buyGreen
        case .mined: return CRBTheme.Colors.warning
        case .unknown: return CRBTheme.Colors.muted
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(AppState())
    }
}
