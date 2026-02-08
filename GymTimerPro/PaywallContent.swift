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
                title: "Desbloquea tu modo Pro",
                subtitle: "Rutinas, progreso y ajustes sin límites.",
                benefitsTitle: "Beneficios clave",
                bullets: [
                    "Entrena sin cortes por límite diario.",
                    "Guarda rutinas y repítelas en segundos.",
                    "Mide progreso para mantener constancia."
                ],
                plansTitle: "Elige plan",
                annualLabel: "Anual",
                annualBadge: "Mejor valor",
                monthlyLabel: "Mensual",
                monthlyBadge: nil,
                ctaPrimary: "Empezar gratis",
                ctaSecondary: "Ahora no",
                ctaSecondaryAction: .dismiss,
                trustLine: "Cancela cuando quieras desde tu Apple ID.",
                legalLine1: "Suscripción auto-renovable con prueba de 2 semanas.",
                legalLine2: "Luego se cobra el plan elegido hasta que canceles.",
                includeSectionTitle: nil,
                includeItems: []
            )
        case .dailyLimitDuringWorkout:
            return PaywallCopy(
                title: "Sigue el entreno sin cortes",
                subtitle: "Hoy llegaste al límite free.",
                benefitsTitle: "Beneficios clave",
                bullets: [
                    "Continúa ahora mismo tu sesión.",
                    "Sin límite diario mientras progresas.",
                    "Todo tu flujo en una sola app."
                ],
                plansTitle: "Elige plan",
                annualLabel: "Anual",
                annualBadge: "Mejor valor",
                monthlyLabel: "Mensual",
                monthlyBadge: nil,
                ctaPrimary: "Empezar gratis",
                ctaSecondary: "Ahora no",
                ctaSecondaryAction: .dismiss,
                trustLine: "Empiezas gratis y puedes cancelar cuando quieras.",
                legalLine1: "Suscripción auto-renovable con prueba de 2 semanas.",
                legalLine2: "Luego se cobra el plan elegido hasta que canceles.",
                includeSectionTitle: nil,
                includeItems: []
            )
        }
    }

    private static func standardCopy(for entryPoint: PaywallEntryPoint) -> PaywallCopy {
        switch entryPoint {
        case .proModule:
            return PaywallCopy(
                title: "Entrena con todo el potencial",
                subtitle: "Desbloquea rutinas, progreso y control total.",
                benefitsTitle: "Lo que ganas",
                bullets: [
                    "Flujo completo de entrenamiento sin fricción.",
                    "Rutinas listas para repetir cuando quieras.",
                    "Progreso claro para sostener el hábito."
                ],
                plansTitle: "Selecciona tu plan",
                annualLabel: "Plan anual",
                annualBadge: "Mejor valor",
                monthlyLabel: "Plan mensual",
                monthlyBadge: nil,
                ctaPrimary: "Empezar gratis",
                ctaSecondary: nil,
                ctaSecondaryAction: .dismiss,
                trustLine: "Sin permanencia. Gestiona o cancela en Apple.",
                legalLine1: "Prueba gratis 2 semanas. Luego se cobra según el plan.",
                legalLine2: "Renovación automática salvo cancelación previa.",
                includeSectionTitle: nil,
                includeItems: []
            )
        case .dailyLimitDuringWorkout:
            return PaywallCopy(
                title: "No pares tu progreso hoy",
                subtitle: "Pasa a Pro y termina tu sesión sin límite.",
                benefitsTitle: "Lo que ganas",
                bullets: [
                    "Sigue entrenando ahora, sin interrupciones.",
                    "Guarda y reaplica tus rutinas rápido.",
                    "Ve progreso y rachas en un solo lugar."
                ],
                plansTitle: "Selecciona tu plan",
                annualLabel: "Plan anual",
                annualBadge: "Mejor valor",
                monthlyLabel: "Plan mensual",
                monthlyBadge: nil,
                ctaPrimary: "Empezar gratis",
                ctaSecondary: "Ahora no",
                ctaSecondaryAction: .dismiss,
                trustLine: "Sin riesgo: 2 semanas gratis y cancelación libre.",
                legalLine1: "Suscripción auto-renovable. Se cobra al final del trial.",
                legalLine2: "Renovación automática salvo cancelación previa.",
                includeSectionTitle: nil,
                includeItems: []
            )
        }
    }

    private static func detailedCopy(for entryPoint: PaywallEntryPoint) -> PaywallCopy {
        switch entryPoint {
        case .proModule:
            return PaywallCopy(
                title: "Sube de nivel con Pro",
                subtitle: "Todo para entrenar mejor, sin pasos extra.",
                benefitsTitle: "Resultados para tu rutina",
                bullets: [
                    "Completa entrenos sin límite diario.",
                    "Reduce tiempo de preparación con rutinas guardadas.",
                    "Convierte sesiones en progreso medible."
                ],
                plansTitle: "Selecciona tu plan",
                annualLabel: "Plan anual",
                annualBadge: "Mejor valor",
                monthlyLabel: "Plan mensual",
                monthlyBadge: nil,
                ctaPrimary: "Empezar gratis",
                ctaSecondary: nil,
                ctaSecondaryAction: .dismiss,
                trustLine: "Cancela cuando quieras. Sin compromisos largos.",
                legalLine1: "Suscripción auto-renovable con período de prueba gratis.",
                legalLine2: "Incluye restaurar compras, términos y privacidad.",
                includeSectionTitle: "Qué incluye Pro",
                includeItems: [
                    "Rutinas sin límite",
                    "Clasificaciones para ordenar",
                    "Gráficas de progreso",
                    "Calendario de actividad",
                    "Rachas y badges",
                    "Sin límite diario en entreno"
                ]
            )
        case .dailyLimitDuringWorkout:
            return PaywallCopy(
                title: "Termina fuerte, sin límites",
                subtitle: "Activa Pro y continúa este entreno al instante.",
                benefitsTitle: "Resultados para hoy y mañana",
                bullets: [
                    "Sigue esta sesión justo ahora.",
                    "Ahorra tiempo con rutinas reutilizables.",
                    "Mantén constancia con progreso visible."
                ],
                plansTitle: "Selecciona tu plan",
                annualLabel: "Plan anual",
                annualBadge: "Mejor valor",
                monthlyLabel: "Plan mensual",
                monthlyBadge: nil,
                ctaPrimary: "Empezar gratis",
                ctaSecondary: "Ahora no",
                ctaSecondaryAction: .dismiss,
                trustLine: "Comienzas gratis. Cobro solo al terminar la prueba.",
                legalLine1: "Suscripción auto-renovable con renovación automática.",
                legalLine2: "Gestiona o cancela en Apple. Compras restaurables.",
                includeSectionTitle: "Qué incluye Pro",
                includeItems: [
                    "Sin límite diario",
                    "Rutinas y clasificaciones",
                    "Histórico de entrenos",
                    "Gráficas y calendario",
                    "Actividad reciente",
                    "Streaks y badges"
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
