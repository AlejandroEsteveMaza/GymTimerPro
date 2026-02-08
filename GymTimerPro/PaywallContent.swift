import Foundation

enum PaywallEntryPoint: String, Sendable, Hashable {
    case proModule
    case dailyLimitDuringWorkout
}

enum PaywallInfoLevel: String, Sendable, Hashable {
    case light
    case standard
    case detailed
}

enum PaywallSecondaryAction: Sendable, Equatable {
    case dismiss
    case selectMonthly
}

struct PaywallPresentationContext: Identifiable, Hashable, Sendable {
    let entryPoint: PaywallEntryPoint
    let infoLevel: PaywallInfoLevel

    var id: String {
        "\(entryPoint.rawValue)-\(infoLevel.rawValue)"
    }
}

struct PaywallCopy: Equatable, Sendable {
    let title: String
    let subtitle: String
    let benefitsTitle: String
    let bullets: [String]
    let plansTitle: String
    let annualLabel: String
    let annualBadge: String
    let monthlyLabel: String
    let monthlyBadge: String?
    let ctaPrimary: String
    let ctaSecondary: String?
    let ctaSecondaryAction: PaywallSecondaryAction
    let trustLine: String
    let legalLine1: String
    let legalLine2: String
    let includeSectionTitle: String?
    let includeItems: [String]

    static func make(
        entryPoint: PaywallEntryPoint,
        infoLevel: PaywallInfoLevel
    ) -> PaywallCopy {
        switch infoLevel {
        case .light:
            return lightCopy(for: entryPoint)
        case .standard:
            return standardCopy(for: entryPoint)
        case .detailed:
            return detailedCopy(for: entryPoint)
        }
    }

    private static func lightCopy(for entryPoint: PaywallEntryPoint) -> PaywallCopy {
        switch entryPoint {
        case .proModule:
            return PaywallCopy(
                title: L10n.tr("paywall.copy.light.pro.title"),
                subtitle: L10n.tr("paywall.copy.light.pro.subtitle"),
                benefitsTitle: L10n.tr("paywall.copy.light.pro.benefits_title"),
                bullets: [
                    L10n.tr("paywall.copy.light.pro.bullet_1"),
                    L10n.tr("paywall.copy.light.pro.bullet_2"),
                    L10n.tr("paywall.copy.light.pro.bullet_3")
                ],
                plansTitle: L10n.tr("paywall.copy.light.pro.plans_title"),
                annualLabel: L10n.tr("paywall.copy.light.pro.annual_label"),
                annualBadge: L10n.tr("paywall.copy.light.pro.annual_badge"),
                monthlyLabel: L10n.tr("paywall.copy.light.pro.monthly_label"),
                monthlyBadge: nil,
                ctaPrimary: L10n.tr("paywall.copy.light.pro.cta_primary"),
                ctaSecondary: L10n.tr("paywall.copy.light.pro.cta_secondary"),
                ctaSecondaryAction: .dismiss,
                trustLine: L10n.tr("paywall.copy.light.pro.trust"),
                legalLine1: L10n.tr("paywall.copy.light.pro.legal1"),
                legalLine2: L10n.tr("paywall.copy.light.pro.legal2"),
                includeSectionTitle: nil,
                includeItems: []
            )
        case .dailyLimitDuringWorkout:
            return PaywallCopy(
                title: L10n.tr("paywall.copy.light.limit.title"),
                subtitle: L10n.tr("paywall.copy.light.limit.subtitle"),
                benefitsTitle: L10n.tr("paywall.copy.light.limit.benefits_title"),
                bullets: [
                    L10n.tr("paywall.copy.light.limit.bullet_1"),
                    L10n.tr("paywall.copy.light.limit.bullet_2"),
                    L10n.tr("paywall.copy.light.limit.bullet_3")
                ],
                plansTitle: L10n.tr("paywall.copy.light.limit.plans_title"),
                annualLabel: L10n.tr("paywall.copy.light.limit.annual_label"),
                annualBadge: L10n.tr("paywall.copy.light.limit.annual_badge"),
                monthlyLabel: L10n.tr("paywall.copy.light.limit.monthly_label"),
                monthlyBadge: nil,
                ctaPrimary: L10n.tr("paywall.copy.light.limit.cta_primary"),
                ctaSecondary: L10n.tr("paywall.copy.light.limit.cta_secondary"),
                ctaSecondaryAction: .dismiss,
                trustLine: L10n.tr("paywall.copy.light.limit.trust"),
                legalLine1: L10n.tr("paywall.copy.light.limit.legal1"),
                legalLine2: L10n.tr("paywall.copy.light.limit.legal2"),
                includeSectionTitle: nil,
                includeItems: []
            )
        }
    }

    private static func standardCopy(for entryPoint: PaywallEntryPoint) -> PaywallCopy {
        switch entryPoint {
        case .proModule:
            return PaywallCopy(
                title: L10n.tr("paywall.copy.standard.pro.title"),
                subtitle: L10n.tr("paywall.copy.standard.pro.subtitle"),
                benefitsTitle: L10n.tr("paywall.copy.standard.pro.benefits_title"),
                bullets: [
                    L10n.tr("paywall.copy.standard.pro.bullet_1"),
                    L10n.tr("paywall.copy.standard.pro.bullet_2"),
                    L10n.tr("paywall.copy.standard.pro.bullet_3")
                ],
                plansTitle: L10n.tr("paywall.copy.standard.pro.plans_title"),
                annualLabel: L10n.tr("paywall.copy.standard.pro.annual_label"),
                annualBadge: L10n.tr("paywall.copy.standard.pro.annual_badge"),
                monthlyLabel: L10n.tr("paywall.copy.standard.pro.monthly_label"),
                monthlyBadge: nil,
                ctaPrimary: L10n.tr("paywall.copy.standard.pro.cta_primary"),
                ctaSecondary: nil,
                ctaSecondaryAction: .dismiss,
                trustLine: L10n.tr("paywall.copy.standard.pro.trust"),
                legalLine1: L10n.tr("paywall.copy.standard.pro.legal1"),
                legalLine2: L10n.tr("paywall.copy.standard.pro.legal2"),
                includeSectionTitle: nil,
                includeItems: []
            )
        case .dailyLimitDuringWorkout:
            return PaywallCopy(
                title: L10n.tr("paywall.copy.standard.limit.title"),
                subtitle: L10n.tr("paywall.copy.standard.limit.subtitle"),
                benefitsTitle: L10n.tr("paywall.copy.standard.limit.benefits_title"),
                bullets: [
                    L10n.tr("paywall.copy.standard.limit.bullet_1"),
                    L10n.tr("paywall.copy.standard.limit.bullet_2"),
                    L10n.tr("paywall.copy.standard.limit.bullet_3")
                ],
                plansTitle: L10n.tr("paywall.copy.standard.limit.plans_title"),
                annualLabel: L10n.tr("paywall.copy.standard.limit.annual_label"),
                annualBadge: L10n.tr("paywall.copy.standard.limit.annual_badge"),
                monthlyLabel: L10n.tr("paywall.copy.standard.limit.monthly_label"),
                monthlyBadge: nil,
                ctaPrimary: L10n.tr("paywall.copy.standard.limit.cta_primary"),
                ctaSecondary: L10n.tr("paywall.copy.standard.limit.cta_secondary"),
                ctaSecondaryAction: .dismiss,
                trustLine: L10n.tr("paywall.copy.standard.limit.trust"),
                legalLine1: L10n.tr("paywall.copy.standard.limit.legal1"),
                legalLine2: L10n.tr("paywall.copy.standard.limit.legal2"),
                includeSectionTitle: nil,
                includeItems: []
            )
        }
    }

    private static func detailedCopy(for entryPoint: PaywallEntryPoint) -> PaywallCopy {
        switch entryPoint {
        case .proModule:
            return PaywallCopy(
                title: L10n.tr("paywall.copy.detailed.pro.title"),
                subtitle: L10n.tr("paywall.copy.detailed.pro.subtitle"),
                benefitsTitle: L10n.tr("paywall.copy.detailed.pro.benefits_title"),
                bullets: [
                    L10n.tr("paywall.copy.detailed.pro.bullet_1"),
                    L10n.tr("paywall.copy.detailed.pro.bullet_2"),
                    L10n.tr("paywall.copy.detailed.pro.bullet_3")
                ],
                plansTitle: L10n.tr("paywall.copy.detailed.pro.plans_title"),
                annualLabel: L10n.tr("paywall.copy.detailed.pro.annual_label"),
                annualBadge: L10n.tr("paywall.copy.detailed.pro.annual_badge"),
                monthlyLabel: L10n.tr("paywall.copy.detailed.pro.monthly_label"),
                monthlyBadge: nil,
                ctaPrimary: L10n.tr("paywall.copy.detailed.pro.cta_primary"),
                ctaSecondary: nil,
                ctaSecondaryAction: .dismiss,
                trustLine: L10n.tr("paywall.copy.detailed.pro.trust"),
                legalLine1: L10n.tr("paywall.copy.detailed.pro.legal1"),
                legalLine2: L10n.tr("paywall.copy.detailed.pro.legal2"),
                includeSectionTitle: L10n.tr("paywall.copy.detailed.pro.include_title"),
                includeItems: [
                    L10n.tr("paywall.copy.detailed.pro.include_1"),
                    L10n.tr("paywall.copy.detailed.pro.include_2"),
                    L10n.tr("paywall.copy.detailed.pro.include_3"),
                    L10n.tr("paywall.copy.detailed.pro.include_4"),
                    L10n.tr("paywall.copy.detailed.pro.include_5"),
                    L10n.tr("paywall.copy.detailed.pro.include_6")
                ]
            )
        case .dailyLimitDuringWorkout:
            return PaywallCopy(
                title: L10n.tr("paywall.copy.detailed.limit.title"),
                subtitle: L10n.tr("paywall.copy.detailed.limit.subtitle"),
                benefitsTitle: L10n.tr("paywall.copy.detailed.limit.benefits_title"),
                bullets: [
                    L10n.tr("paywall.copy.detailed.limit.bullet_1"),
                    L10n.tr("paywall.copy.detailed.limit.bullet_2"),
                    L10n.tr("paywall.copy.detailed.limit.bullet_3")
                ],
                plansTitle: L10n.tr("paywall.copy.detailed.limit.plans_title"),
                annualLabel: L10n.tr("paywall.copy.detailed.limit.annual_label"),
                annualBadge: L10n.tr("paywall.copy.detailed.limit.annual_badge"),
                monthlyLabel: L10n.tr("paywall.copy.detailed.limit.monthly_label"),
                monthlyBadge: nil,
                ctaPrimary: L10n.tr("paywall.copy.detailed.limit.cta_primary"),
                ctaSecondary: L10n.tr("paywall.copy.detailed.limit.cta_secondary"),
                ctaSecondaryAction: .dismiss,
                trustLine: L10n.tr("paywall.copy.detailed.limit.trust"),
                legalLine1: L10n.tr("paywall.copy.detailed.limit.legal1"),
                legalLine2: L10n.tr("paywall.copy.detailed.limit.legal2"),
                includeSectionTitle: L10n.tr("paywall.copy.detailed.limit.include_title"),
                includeItems: [
                    L10n.tr("paywall.copy.detailed.limit.include_1"),
                    L10n.tr("paywall.copy.detailed.limit.include_2"),
                    L10n.tr("paywall.copy.detailed.limit.include_3"),
                    L10n.tr("paywall.copy.detailed.limit.include_4"),
                    L10n.tr("paywall.copy.detailed.limit.include_5"),
                    L10n.tr("paywall.copy.detailed.limit.include_6")
                ]
            )
        }
    }
}

enum PaywallPlanDefaults {
    static func defaultProductID(availableIDs: [String]) -> String? {
        if availableIDs.contains(PurchaseManager.annualProductID) {
            return PurchaseManager.annualProductID
        }
        return availableIDs.first
    }
}
