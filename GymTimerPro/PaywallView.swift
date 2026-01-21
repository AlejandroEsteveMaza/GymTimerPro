import StoreKit
import SwiftUI

struct PaywallView: View {
    let dailyLimit: Int
    let consumedToday: Int
    let accentColor: Color

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isProcessing = false
    @State private var error: PurchaseManager.PurchaseError?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    valueSection

                    SectionHeader(titleKey: "paywall.section.benefits")
                    benefitsSection

                    SectionHeader(titleKey: "paywall.section.purchase")
                    purchaseSection

                    ctaSection
                    secondaryActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isProcessing)
                    .accessibilityLabel(Text("common.cancel"))
                }
            }
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

    private var priceText: String {
        if let product = purchaseManager.proProduct {
            return product.displayPrice
        }
        return L10n.tr("paywall.price.loading")
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("paywall.badge.pro")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.15), in: Capsule())

            Text("paywall.value.title")
                .font(.title.bold())
                .foregroundStyle(.primary)

            Text("paywall.value.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(L10n.format("paywall.subtitle_limit_format", consumedToday, dailyLimit), systemImage: "exclamationmark.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenefitRow(icon: "infinity", titleKey: "paywall.benefit.unlimited")
            Divider().foregroundStyle(Color(uiColor: .separator))
            BenefitRow(icon: "calendar.badge.checkmark", titleKey: "paywall.benefit.no_limits")
            Divider().foregroundStyle(Color(uiColor: .separator))
            BenefitRow(icon: "creditcard", titleKey: "paywall.benefit.one_time")
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var purchaseSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("paywall.purchase.option_title")
                    .font(.headline)
                Text("paywall.purchase.option_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(priceText)
                    .font(.title3.bold())
                Text("paywall.purchase.one_time")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var ctaSection: some View {
        Button {
            Task { await buy() }
        } label: {
            Text("paywall.button.buy")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(accentColor)
        .disabled(isProcessing || purchaseManager.isLoading)
    }

    private var secondaryActions: some View {
        VStack(spacing: 10) {
            Button("paywall.button.restore") {
                Task { await restore() }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            Button("paywall.button.terms") {
                if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    openURL(url)
                }
            }
            .buttonStyle(.plain)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
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

private struct SectionHeader: View {
    let titleKey: String

    var body: some View {
        Text(LocalizedStringKey(titleKey))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BenefitRow: View {
    let icon: String
    let titleKey: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(LocalizedStringKey(titleKey))
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }
}
