import Foundation
import StoreKit
import Observation

enum PurchaseOutcome: Equatable {
    case success
    case cancelled
    case pending
    case failed(String)
}

private enum PurchaseVerificationError: Error {
    case unverified
}

@MainActor
@Observable
final class PurchaseService {
    static let shared = PurchaseService()

    enum ProductID: String, CaseIterable {
        case monthly = "smallpanta-icould.com.caelynperiodtracker.pro.monthly"
        case yearly  = "smallpanta-icould.com.caelynperiodtracker.pro.yearly"
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var lastError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
    }

    // MARK: - Derived state

    var isPro: Bool { !purchasedProductIDs.isEmpty }

    var monthlyProduct: Product? { products.first(where: { $0.id == ProductID.monthly.rawValue }) }
    var yearlyProduct:  Product? { products.first(where: { $0.id == ProductID.yearly.rawValue  }) }

    /// "Save N%" badge for the yearly tier, derived from monthly × 12 vs yearly.
    var yearlySavingsPercent: Int {
        guard let monthly = monthlyProduct, let yearly = yearlyProduct else { return 0 }
        return Self.savingsPercent(monthlyPrice: monthly.price, yearlyPrice: yearly.price)
    }

    /// Pure helper for unit tests — savings % of yearly vs paying monthly for 12 months.
    static func savingsPercent(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int {
        let monthlyAnnual = monthlyPrice * 12
        guard monthlyAnnual > 0 else { return 0 }
        let saved = monthlyAnnual - yearlyPrice
        let percent = (saved / monthlyAnnual) * 100
        return Int(NSDecimalNumber(decimal: percent).rounding(accordingToBehavior: nil).doubleValue)
    }

    // MARK: - Loading

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        lastError = nil

        let ids = Set(ProductID.allCases.map(\.rawValue))
        do {
            products = try await Product.products(for: ids)
            await refreshPurchasedProducts()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Purchase + restore

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshPurchasedProducts()
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Internals

    private func refreshPurchasedProducts() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.refreshPurchasedProducts()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:           throw PurchaseVerificationError.unverified
        case .verified(let value):  return value
        }
    }
}
