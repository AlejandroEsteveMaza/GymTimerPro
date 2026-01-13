import StoreKit
import SwiftUI

struct PaywallView: View {
    let dailyLimit: Int
    let consumedToday: Int

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var error: PurchaseManager.PurchaseError?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("paywall.title")
                            .font(.title.bold())
                        Text(L10n.format("paywall.subtitle_limit_format", consumedToday, dailyLimit))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("paywall.benefit.unlimited", systemImage: "infinity")
                            .font(.headline)
                        Label("paywall.benefit.simple", systemImage: "timer")
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(spacing: 12) {
                        Button {
                            Task { await buy() }
                        } label: {
                            VStack(spacing: 2) {
                                Text("paywall.button.buy")
                                    .font(.headline)
                                Text(priceLine)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing || purchaseManager.isLoading)

                        Button("paywall.button.restore") {
                            Task { await restore() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)

                        Button("paywall.button.not_now") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isProcessing)
        .task {
            await purchaseManager.refresh()
            if purchaseManager.isPro {
                dismiss()
            }
        }
        .onChange(of: purchaseManager.isPro) { _, isPro in
            if isPro {
                dismiss()
            }
        }
        .alert(
            Text("paywall.error.title"),
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )
        ) {
            Button("common.ok") { error = nil }
        } message: {
            Text(error?.localizedDescription ?? L10n.tr("paywall.error.unknown"))
        }
    }

    private var priceLine: String {
        if let product = purchaseManager.proProduct {
            return product.displayPrice
        }
        return L10n.tr("paywall.price.loading")
    }

    private func buy() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await purchaseManager.purchasePro()
        } catch let purchaseError as PurchaseManager.PurchaseError {
            if purchaseError != .userCancelled {
                error = purchaseError
            }
        } catch {
            self.error = .unknown
        }
    }

    private func restore() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await purchaseManager.restorePurchases()
        } catch {
            self.error = .unknown
        }
    }
}

