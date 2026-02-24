import StoreKit
import SwiftUI

struct PaywallView: View {
    let dailyLimit: Int
    let consumedToday: Int
    let accentColor: Color
    let entryPoint: PaywallEntryPoint
    let infoLevel: PaywallInfoLevel

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isProcessing = false
    @State private var error: PurchaseManager.PurchaseError?
    @State private var selectedProductID: String?
    @State private var infoMessage: String?

    init(
        dailyLimit: Int,
        consumedToday: Int,
        accentColor: Color,
        entryPoint: PaywallEntryPoint = .proModule,
        infoLevel: PaywallInfoLevel = .standard
    ) {
        self.dailyLimit = dailyLimit
        self.consumedToday = consumedToday
        self.accentColor = accentColor
        self.entryPoint = entryPoint
        self.infoLevel = infoLevel
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    benefitsSection
                    if let includeTitle = copy.includeSectionTitle, !copy.includeItems.isEmpty {
                        includeSection(title: includeTitle, items: copy.includeItems)
                    }
                    plansSection
                    ctaSection
                    legalSection
                    linksSection
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
            selectDefaultProductIfNeeded()
            if purchaseManager.isPro {
                dismiss()
            }
        }
        .onChange(of: productIDsKey) { _, _ in
            selectDefaultProductIfNeeded()
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
        .alert(
            "paywall.info.title",
            isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )
        ) {
            Button("common.ok") { infoMessage = nil }
        } message: {
            Text(infoMessage ?? "")
        }
    }

    private var copy: PaywallCopy {
        PaywallCopy.make(entryPoint: entryPoint, infoLevel: infoLevel)
    }

    private var productIDsKey: String {
        orderedProducts.map(\.id).joined(separator: "|")
    }

    private var orderedProducts: [Product] {
        purchaseManager.proProducts.sorted {
            planPriority(for: $0) < planPriority(for: $1)
        }
    }

    private var annualProduct: Product? {
        orderedProducts.first(where: { planKind(for: $0) == .yearly })
    }

    private var monthlyProduct: Product? {
        orderedProducts.first(where: { planKind(for: $0) == .monthly })
    }

    private var hasReachedDailyLimit: Bool {
        consumedToday >= dailyLimit
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("paywall.badge.pro")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(accentColor.opacity(0.15), in: Capsule())

            Text(copy.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(copy.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if hasReachedDailyLimit {
                Text(L10n.format("paywall.subtitle_limit_format", consumedToday, dailyLimit))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(copy.benefitsTitle)
            ForEach(copy.bullets.prefix(3), id: \.self) { bullet in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accentColor)
                    Text(bullet)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func includeSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 7)
                    Text(item)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(copy.plansTitle)
            if let trialText = trialIncentiveText {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(accentColor)
                    Text(trialText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(accentColor.opacity(0.12), in: Capsule())
            }
            if orderedProducts.isEmpty {
                Text("paywall.price.loading")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(orderedProducts, id: \.id) { product in
                    planCard(product)
                }
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isAnnual = planKind(for: product) == .yearly
        let planLabel = isAnnual ? copy.annualLabel : copy.monthlyLabel
        let badge = isAnnual ? copy.annualBadge : copy.monthlyBadge

        return Button {
            selectedProductID = product.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? accentColor : .secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(planLabel)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(accentColor.opacity(0.14), in: Capsule())
                        }
                    }

                    Spacer(minLength: 0)

                    Text(priceLine(for: product))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var ctaSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await buy() }
            } label: {
                Text(copy.ctaPrimary)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(accentColor)
            .disabled(isProcessing || purchaseManager.isLoading || selectedProductID == nil)

            if let secondary = copy.ctaSecondary {
                Button(secondary) {
                    handleSecondaryAction()
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }

            Text(copy.trustLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(copy.legalLine1)
            Text(copy.legalLine2)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var linksSection: some View {
        VStack(spacing: 10) {
            Button(L10n.tr("paywall.button.restore")) {
                Task { await restore() }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            if let manageURL {
                Button(L10n.tr("paywall.button.manage")) {
                    openURL(manageURL)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }

            HStack(spacing: 16) {
                if let termsURL {
                    Button(L10n.tr("paywall.button.terms")) {
                        openURL(termsURL)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }

                if let privacyURL {
                    Button(L10n.tr("paywall.button.privacy")) {
                        openURL(privacyURL)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private var termsURL: URL? {
        let fallback = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        let value = Bundle.main.object(forInfoDictionaryKey: "PAYWALL_TERMS_URL") as? String
        return URL(string: value ?? fallback)
    }

    private var privacyURL: URL? {
        let fallback = "https://www.apple.com/legal/privacy/"
        let value = Bundle.main.object(forInfoDictionaryKey: "PAYWALL_PRIVACY_URL") as? String
        return URL(string: value ?? fallback)
    }

    private var manageURL: URL? {
        URL(string: "https://apps.apple.com/account/subscriptions")
    }

    private var trialIncentiveText: String? {
        let annualPeriod = trialPeriodIfFree(annualProduct?.subscription?.introductoryOffer)
        let monthlyPeriod = trialPeriodIfFree(monthlyProduct?.subscription?.introductoryOffer)

        if let annualPeriod, let monthlyPeriod, isSamePeriod(annualPeriod, monthlyPeriod) {
            return L10n.format("paywall.trial_incentive_format", periodText(for: annualPeriod))
        }

        if let period = annualPeriod ?? monthlyPeriod {
            return L10n.format("paywall.trial_incentive_format", periodText(for: period))
        }

        return nil
    }

    private func trialPeriodIfFree(
        _ offer: Product.SubscriptionOffer?
    ) -> Product.SubscriptionPeriod? {
        guard let offer, offer.paymentMode == .freeTrial else { return nil }
        return offer.period
    }

    private func isSamePeriod(
        _ lhs: Product.SubscriptionPeriod,
        _ rhs: Product.SubscriptionPeriod
    ) -> Bool {
        lhs.unit == rhs.unit && lhs.value == rhs.value
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleSecondaryAction() {
        switch copy.ctaSecondaryAction {
        case .dismiss:
            dismiss()
        }
    }

    private func buy() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            guard let selectedProductID else {
                throw PurchaseManager.PurchaseError.productUnavailable
            }
            try await purchaseManager.purchase(productID: selectedProductID)
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
            if !purchaseManager.isPro {
                infoMessage = L10n.tr("paywall.restore.no_purchases")
            }
        } catch {
            self.error = .unknown
        }
    }

    private func selectDefaultProductIfNeeded() {
        guard !orderedProducts.isEmpty else {
            selectedProductID = nil
            return
        }

        if selectedProductID == nil || purchaseManager.proProductsByID[selectedProductID ?? ""] == nil {
            let availableIDs = orderedProducts.map(\.id)
            selectedProductID = PaywallPlanDefaults.defaultProductID(availableIDs: availableIDs)
        }
    }

    private func planPriority(for product: Product) -> Int {
        switch planKind(for: product) {
        case .yearly:
            return 0
        case .monthly:
            return 1
        case .other:
            return 2
        }
    }

    private func priceLine(for product: Product) -> String {
        "\(product.displayPrice)/\(periodShortText(for: product))"
    }

    private enum PlanKind {
        case yearly
        case monthly
        case other
    }

    private func planKind(for product: Product) -> PlanKind {
        guard let period = product.subscription?.subscriptionPeriod else {
            return .other
        }
        switch period.unit {
        case .month where period.value == 1:
            return .monthly
        case .year where period.value == 1:
            return .yearly
        default:
            return .other
        }
    }

    private func periodShortText(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return L10n.tr("paywall.period.generic")
        }
        if period.value == 1 {
            return periodUnitText(for: period.unit)
        }
        return formattedPeriod(value: period.value, unit: period.unit)
            ?? L10n.tr("paywall.period.generic")
    }

    private func periodText(for period: Product.SubscriptionPeriod) -> String {
        formattedPeriod(value: period.value, unit: period.unit)
            ?? L10n.tr("paywall.period.generic")
    }

    private func periodUnitText(for unit: Product.SubscriptionPeriod.Unit) -> String {
        let formatted = formattedPeriod(value: 1, unit: unit) ?? L10n.tr("paywall.period.generic")
        let localizedOne = NumberFormatter.localizedString(from: 1 as NSNumber, number: .none)
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(localizedOne) {
            let withoutNumber = trimmed.dropFirst(localizedOne.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !withoutNumber.isEmpty {
                return String(withoutNumber)
            }
        }
        let withoutDigits = trimmed.unicodeScalars.filter { !CharacterSet.decimalDigits.contains($0) }
        let collapsed = String(String.UnicodeScalarView(withoutDigits)).trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? formatted : collapsed
    }

    private func formattedPeriod(
        value: Int,
        unit: Product.SubscriptionPeriod.Unit
    ) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.zeroFormattingBehavior = .dropAll
        formatter.calendar = Calendar.current

        var components = DateComponents()
        switch unit {
        case .day:
            components.day = value
            formatter.allowedUnits = [.day]
        case .week:
            components.weekOfYear = value
            formatter.allowedUnits = [.weekOfYear]
        case .month:
            components.month = value
            formatter.allowedUnits = [.month]
        case .year:
            components.year = value
            formatter.allowedUnits = [.year]
        @unknown default:
            return nil
        }
        return formatter.string(from: components)
    }
}
