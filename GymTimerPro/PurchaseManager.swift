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
                return L10n.tr("paywall.error.product_unavailable")
            case .failedVerification:
                return L10n.tr("paywall.error.failed_verification")
            case .userCancelled:
                return L10n.tr("paywall.error.user_cancelled")
            case .pending:
                return L10n.tr("paywall.error.pending")
            case .unknown:
                return L10n.tr("paywall.error.unknown")
            }
        }
    }

    @Published private(set) var isPro: Bool
    @Published private(set) var proProduct: Product?
    @Published private(set) var isLoading: Bool = false

    private let storage: UserDefaults
    private var updatesTask: Task<Void, Never>?

    private enum Keys {
        static let cachedIsPro = "purchase.cachedIsPro"
    }

    // App Store Connect product id (Non-Consumable).
    static let proProductID = "gymtimerpro.pro"

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
        guard let proProduct else { throw PurchaseError.productUnavailable }
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
        guard proProduct == nil else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            proProduct = nil
        }
    }

    private func updateEntitlements() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.proProductID else { continue }
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
