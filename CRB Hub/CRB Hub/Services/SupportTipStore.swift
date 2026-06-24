import Foundation
import StoreKit

@MainActor
@Observable
final class SupportTipStore {
    static let productIDs = [
        "crbhub.tip.small",
        "crbhub.tip.medium",
        "crbhub.tip.large"
    ]

    var products: [Product] = []
    var isLoading = false
    var isPurchasing = false
    var message: String?
    var errorMessage: String?

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        errorMessage = nil

        do {
            let fetched = try await Product.products(for: Self.productIDs)
            products = fetched.sorted { $0.price < $1.price }
            if products.isEmpty {
                message = "Support tips are not available yet."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        message = nil
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                message = "Thank you for supporting CRB Hub."
            case .userCancelled:
                break
            case .pending:
                message = "Purchase is pending approval."
            @unknown default:
                message = "Purchase could not be completed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreKitError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            "The purchase could not be verified."
        }
    }
}
