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
        case monthly  = "smallpanta-icould.com.caelynperiodtracker.pro.monthly"
        case yearly   = "smallpanta-icould.com.caelynperiodtracker.pro.yearly"
        case lifetime = "smallpanta-icould.com.caelynperiodtracker.pro.lifetime"
    }

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var lastError: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        // Resolve entitlements from the local StoreKit cache at launch, independent of
        // any product network fetch. Otherwise an offline cold launch leaves a paying
        // Pro user downgraded to free until loadProducts() succeeds (stz-005).
        Task { await refreshPurchasedProducts() }
    }

    // MARK: - Derived state

    private var proOverride: Bool? = nil
    var isPro: Bool { proOverride ?? !purchasedProductIDs.isEmpty }

    /// Forces isPro to a fixed value — used in screenshot mode only.
    func overridePro(_ value: Bool) { proOverride = value }

    var monthlyProduct:  Product? { products.first(where: { $0.id == ProductID.monthly.rawValue  }) }
    var yearlyProduct:   Product? { products.first(where: { $0.id == ProductID.yearly.rawValue   }) }
    var lifetimeProduct: Product? { products.first(where: { $0.id == ProductID.lifetime.rawValue }) }

    /// Whether the product's introductory (free-trial) offer is still available to
    /// this Apple ID. Non-subscription products (lifetime) always return false, and
    /// ineligible users must never be shown trial copy (mon-2).
    func isEligibleForIntroOffer(_ product: Product) async -> Bool {
        guard let sub = product.subscription else { return false }
        return await sub.isEligibleForIntroOffer
    }

    /// A user-facing free-trial label derived from the product's ACTUAL introductory
    /// offer — only when the user is eligible AND the offer is a genuine free trial.
    /// Returns nil otherwise, so the paywall never advertises a trial (or a duration)
    /// that App Store Connect didn't actually grant (review — App-Review 3.1.2/2.3.1).
    func freeTrialLabel(for product: Product) async -> String? {
        guard let sub = product.subscription,
              let offer = sub.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await sub.isEligibleForIntroOffer else { return nil }
        let value = offer.period.value
        let unit: String
        switch offer.period.unit {
        case .day:   unit = value == 1 ? "day" : "days"
        case .week:  unit = value == 1 ? "week" : "weeks"
        case .month: unit = value == 1 ? "month" : "months"
        case .year:  unit = value == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return "\(value)-\(unit) free trial"
    }

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
        lastError = nil
        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
        } catch StoreKitError.userCancelled {
            // User dismissed the Apple ID sign-in sheet — not a failure, don't
            // surface a connectivity error for it (review).
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
