import Combine
import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    enum PurchaseError: LocalizedError, Equatable {
        case productUnavailable
        case failedVerification
        case userCancelled
        case pending
        case unknown

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return NSLocalizedString("paywall.error.product_unavailable", comment: "")
            case .failedVerification:
                return NSLocalizedString("paywall.error.failed_verification", comment: "")
            case .userCancelled:
                return NSLocalizedString("paywall.error.user_cancelled", comment: "")
            case .pending:
                return NSLocalizedString("paywall.error.pending", comment: "")
            case .unknown:
                return NSLocalizedString("paywall.error.unknown", comment: "")
            }
        }
    }

    @Published private(set) var isPro: Bool
    @Published private(set) var proProductsByID: [String: Product] = [:]
    @Published private(set) var isLoading: Bool = false

    private let storage: UserDefaults
    private var updatesTask: Task<Void, Never>?

    private enum Keys {
        static let cachedIsPro = "purchase.cachedIsPro"
    }

    static let monthlyProductID = "premium_monthly"
    static let annualProductID = "premium_yearly"
    static let proProductIDs = [annualProductID, monthlyProductID]

    var proProducts: [Product] {
        Self.proProductIDs.compactMap { proProductsByID[$0] }
    }

    init(storage: UserDefaults = .standard, startTasks: Bool = true) {
        self.storage = storage
        self.isPro = storage.bool(forKey: Keys.cachedIsPro)

        guard startTasks else { return }

        updatesTask = Task { [weak self] in
            guard let self else { return }
            await self.listenForTransactions()
        }

        Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        await loadProducts()
        await updateEntitlements()
    }

    func purchasePro() async throws {
        let defaultProductID = proProductsByID[Self.annualProductID]?.id ?? proProducts.first?.id
        guard let defaultProductID else {
            throw PurchaseError.productUnavailable
        }
        try await purchase(productID: defaultProductID)
    }

    func purchase(productID: String) async throws {
        guard let proProduct = proProductsByID[productID] else {
            throw PurchaseError.productUnavailable
        }
        let result = try await proProduct.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            await updateEntitlements()
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateEntitlements()
    }

    private func loadProducts() async {
        guard proProductsByID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: Self.proProductIDs)
            proProductsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            proProductsByID = [:]
        }
    }

    private func updateEntitlements() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.proProductIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                hasPro = true
                break
            }
        }

        if isPro != hasPro {
            isPro = hasPro
        }
        storage.set(hasPro, forKey: Keys.cachedIsPro)
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await updateEntitlements()
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
