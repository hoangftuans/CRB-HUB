import Foundation

struct USDTTransferService {
    static func sendSecure(
        wallet: USDTWallet,
        to recipient: String,
        amount: Decimal,
        safeTradeCodes: SafeTradeWithdrawCodes = SafeTradeWithdrawCodes(),
        fallbackPassword: String? = nil
    ) async throws -> String {
        guard USDTNetwork.isValidP2PAddress(recipient, rail: wallet.network.p2pRail ?? "") || isValidAddress(recipient, network: wallet.network) else {
            throw TransferError.invalidRecipient
        }
        guard amount > 0 else {
            throw TransferError.invalidAmount
        }

        if SafeTradeAPIService.shared.isEnabled {
            if wallet.isNative {
                _ = try await WalletSecurityStore.shared.loadPrivateKeyForTransaction(
                    walletId: wallet.id,
                    amountDescription: "\(CRBUnits.formatDecimal(amount, maxFractionDigits: 6, minFractionDigits: 0)) USDT",
                    fallbackPassword: fallbackPassword
                )
            }
            return try await SafeTradeAPIService.shared.transferUSDT(wallet: wallet, to: recipient, amount: amount, codes: safeTradeCodes)
        }

        if wallet.isNative {
            throw TransferError.signingNotImplemented
        }

        throw TransferError.externalWalletRequiresProvider
    }

    static func isValidAddress(_ address: String, network: USDTNetwork) -> Bool {
        switch network {
        case .polygon:
            return USDTNetwork.isValidP2PAddress(address, rail: "polygon")
        case .solana:
            return USDTNetwork.isValidP2PAddress(address, rail: "solana")
        case .erc20, .bep20:
            let body = String(address.dropFirst(2))
            let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            return address.hasPrefix("0x") && address.count == 42 && body.unicodeScalars.allSatisfy { hex.contains($0) }
        case .trc20:
            return address.hasPrefix("T") && address.count == 34
        }
    }

    enum TransferError: LocalizedError {
        case externalWalletRequiresProvider
        case invalidRecipient
        case invalidAmount
        case signingNotImplemented

        var errorDescription: String? {
            switch self {
            case .externalWalletRequiresProvider:
                return "This linked USDT wallet is external. Open its provider wallet to send funds."
            case .invalidRecipient:
                return "Recipient address does not match this USDT network."
            case .invalidAmount:
                return "Invalid USDT amount."
            case .signingNotImplemented:
                return "Native USDT signing is not implemented yet. Face ID/password protection is ready, but live USDT broadcast must be implemented and audited before sending."
            }
        }
    }
}
