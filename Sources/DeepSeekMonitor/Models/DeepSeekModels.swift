import Foundation

enum MonitorSection: String, CaseIterable, Identifiable {
    case overview
    case usage
    case costs
    case models
    case status
    case alerts
    case settings

    var id: String { rawValue }

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview: language.isChinese ? "概览" : "Overview"
        case .usage: language.isChinese ? "用量" : "Usage"
        case .costs: language.isChinese ? "成本" : "Costs"
        case .models: language.isChinese ? "模型" : "Models"
        case .status: language.isChinese ? "服务状态" : "Status"
        case .alerts: language.isChinese ? "告警" : "Alerts"
        case .settings: language.isChinese ? "设置" : "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge.with.dots.needle.67percent"
        case .usage: "chart.xyaxis.line"
        case .costs: "yensign.circle"
        case .models: "square.stack.3d.up"
        case .status: "checkmark.rectangle.stack"
        case .alerts: "bell.badge"
        case .settings: "gearshape"
        }
    }
}

struct AccountSummary: Equatable, Sendable {
    var balance: Decimal
    var bonusBalance: Decimal
    var currency: String
    var estimatedAvailableTokens: Int
    var monthlyCost: Decimal
    var monthlyTokenUsage: Int
    var currentToken: Int

    static let empty = AccountSummary(
        balance: 0,
        bonusBalance: 0,
        currency: "CNY",
        estimatedAvailableTokens: 0,
        monthlyCost: 0,
        monthlyTokenUsage: 0,
        currentToken: 0
    )
}

struct UsageBreakdown: Equatable, Sendable {
    var month: Int
    var year: Int
    var modelTotals: [ModelMetric]
    var dailyTotals: [DailyMetric]

    var today: DailyMetric? {
        let calendar = Calendar.current
        return dailyTotals.first { calendar.isDateInToday($0.date) }
    }

    static let empty = UsageBreakdown(month: 1, year: 2026, modelTotals: [], dailyTotals: [])
}

struct CostBreakdown: Equatable, Sendable {
    var month: Int
    var year: Int
    var currency: String
    var modelTotals: [ModelMetric]
    var dailyTotals: [DailyMetric]

    static let empty = CostBreakdown(month: 1, year: 2026, currency: "CNY", modelTotals: [], dailyTotals: [])
}

struct ModelMetric: Identifiable, Equatable, Sendable {
    var model: String
    var metrics: [MetricValue]

    var id: String { model }

    var total: Decimal {
        metrics.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var requestCount: Int {
        NSDecimalNumber(decimal: amount(for: .request)).intValue
    }

    var tokenTotal: Decimal {
        UsageType.tokenTypes.reduce(Decimal.zero) { $0 + amount(for: $1) }
    }

    var cacheHitTokens: Decimal {
        amount(for: .promptCacheHitToken)
    }

    var cacheMissTokens: Decimal {
        amount(for: .promptCacheMissToken)
    }

    var responseTokens: Decimal {
        amount(for: .responseToken)
    }

    func amount(for type: UsageType) -> Decimal {
        metrics.first(where: { $0.type == type })?.amount ?? 0
    }
}

struct DailyMetric: Identifiable, Equatable, Sendable {
    var date: Date
    var models: [ModelMetric]

    var id: Date { date }

    var total: Decimal {
        models.reduce(Decimal.zero) { $0 + $1.total }
    }

    var requests: Int {
        NSDecimalNumber(decimal: models.reduce(Decimal.zero) { $0 + $1.amount(for: .request) }).intValue
    }

    var tokenTotal: Decimal {
        models.reduce(Decimal.zero) { $0 + $1.tokenTotal }
    }

    func amount(for type: UsageType) -> Decimal {
        models.reduce(Decimal.zero) { $0 + $1.amount(for: type) }
    }
}

struct MetricValue: Identifiable, Equatable, Sendable {
    var type: UsageType
    var amount: Decimal

    var id: UsageType { type }
}

enum UsageType: String, CaseIterable, Codable, Sendable {
    case promptToken = "PROMPT_TOKEN"
    case promptCacheHitToken = "PROMPT_CACHE_HIT_TOKEN"
    case promptCacheMissToken = "PROMPT_CACHE_MISS_TOKEN"
    case responseToken = "RESPONSE_TOKEN"
    case request = "REQUEST"
    case unknown

    init(rawAPIValue: String) {
        self = UsageType(rawValue: rawAPIValue) ?? .unknown
    }

    static let tokenTypes: [UsageType] = [
        .promptToken,
        .promptCacheHitToken,
        .promptCacheMissToken,
        .responseToken
    ]

    static let visibleTypes: [UsageType] = [
        .request,
        .promptCacheHitToken,
        .promptCacheMissToken,
        .responseToken
    ]

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .promptToken: language.isChinese ? "提示词 Token" : "Prompt"
        case .promptCacheHitToken: language.isChinese ? "缓存命中" : "Cache hit"
        case .promptCacheMissToken: language.isChinese ? "缓存未命中" : "Cache miss"
        case .responseToken: language.isChinese ? "响应 Token" : "Response"
        case .request: language.isChinese ? "API 请求数" : "Requests"
        case .unknown: language.isChinese ? "未知" : "Unknown"
        }
    }
}

extension Array where Element == ModelMetric {
    var requestCount: Int {
        reduce(0) { $0 + $1.requestCount }
    }

    var tokenTotal: Decimal {
        reduce(Decimal.zero) { $0 + $1.tokenTotal }
    }

    func amount(for type: UsageType) -> Decimal {
        reduce(Decimal.zero) { $0 + $1.amount(for: type) }
    }
}

struct AlertRule: Equatable, Sendable {
    var balanceThreshold: Decimal
    var monthlyCostThreshold: Decimal
    var monthlyTokenThreshold: Int
    var refreshIntervalMinutes: Int

    static let defaults = AlertRule(
        balanceThreshold: 50,
        monthlyCostThreshold: 100,
        monthlyTokenThreshold: 100_000_000,
        refreshIntervalMinutes: 15
    )
}

struct AlertEvent: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var detail: String
    var date: Date
}

struct MonitorSnapshot: Equatable, Sendable {
    var account: AccountSummary
    var usage: UsageBreakdown
    var costs: CostBreakdown
    var refreshedAt: Date
}

enum ServiceHealth: String, Codable, Equatable, Sendable {
    case operational
    case degraded
    case outage
    case maintenance
    case unknown

    init(colorHex: String) {
        switch colorHex.lowercased() {
        case "#22c55e", "#10b981", "#16a34a":
            self = .operational
        case "#eab308", "#f97316", "#f59e0b":
            self = .degraded
        case "#ef4444", "#dc2626":
            self = .outage
        default:
            self = .unknown
        }
    }

    var severity: Int {
        switch self {
        case .outage: 4
        case .degraded: 3
        case .maintenance: 2
        case .unknown: 1
        case .operational: 0
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .operational: language.isChinese ? "运行正常" : "Operational"
        case .degraded: language.isChinese ? "性能下降" : "Degraded"
        case .outage: language.isChinese ? "服务不可用" : "Outage"
        case .maintenance: language.isChinese ? "维护中" : "Maintenance"
        case .unknown: language.isChinese ? "未知" : "Unknown"
        }
    }
}

struct OfficialServiceStatus: Equatable, Sendable {
    var summary: ServiceHealth
    var summaryTitle: String
    var summaryDetail: String
    var components: [ServiceComponentStatus]
    var incidents: [ServiceIncident]
    var sourceURL: URL
    var refreshedAt: Date

    static let sourceURL = URL(string: "https://status.deepseek.com/")!
}

struct ServiceComponentStatus: Identifiable, Equatable, Sendable {
    var id: String { name }
    var name: String
    var uptime: String
    var currentHealth: ServiceHealth
    var days: [ServiceStatusDay]
}

struct ServiceStatusDay: Identifiable, Equatable, Sendable {
    var date: Date
    var health: ServiceHealth

    var id: Date { date }
}

struct ServiceIncident: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var link: URL?
    var updatedAt: Date
    var status: String
    var affectedComponents: [String]
}
