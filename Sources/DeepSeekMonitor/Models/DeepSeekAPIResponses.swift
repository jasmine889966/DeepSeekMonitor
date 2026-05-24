import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    var code: Int
    var msg: String
    var data: BusinessEnvelope<T>?
}

struct BusinessEnvelope<T: Decodable>: Decodable {
    var bizCode: Int?
    var bizMsg: String?
    var bizData: T?

    enum CodingKeys: String, CodingKey {
        case bizCode = "biz_code"
        case bizMsg = "biz_msg"
        case bizData = "biz_data"
    }
}

struct UserSummaryDTO: Decodable {
    var currentToken: FlexibleInt?
    var monthlyUsage: FlexibleInt?
    var totalUsage: FlexibleInt?
    var normalWallets: [WalletDTO]
    var bonusWallets: [WalletDTO]
    var totalAvailableTokenEstimation: FlexibleInt?
    var monthlyCosts: [MoneyDTO]
    var monthlyTokenUsage: FlexibleInt?

    enum CodingKeys: String, CodingKey {
        case currentToken = "current_token"
        case monthlyUsage = "monthly_usage"
        case totalUsage = "total_usage"
        case normalWallets = "normal_wallets"
        case bonusWallets = "bonus_wallets"
        case totalAvailableTokenEstimation = "total_available_token_estimation"
        case monthlyCosts = "monthly_costs"
        case monthlyTokenUsage = "monthly_token_usage"
    }
}

struct WalletDTO: Decodable {
    var currency: String
    var balance: FlexibleDecimal
    var tokenEstimation: FlexibleInt?

    enum CodingKeys: String, CodingKey {
        case currency
        case balance
        case tokenEstimation = "token_estimation"
    }
}

struct MoneyDTO: Decodable {
    var currency: String
    var amount: FlexibleDecimal
}

struct UsageDTO: Decodable {
    var total: [ModelUsageDTO]
    var days: [DailyUsageDTO]
}

struct CostDTO: Decodable {
    var total: [ModelUsageDTO]
    var days: [DailyUsageDTO]
    var currency: String?
}

struct ModelUsageDTO: Decodable {
    var model: String
    var usage: [MetricDTO]
}

struct DailyUsageDTO: Decodable {
    var date: String
    var data: [ModelUsageDTO]
}

struct MetricDTO: Decodable {
    var type: String
    var amount: FlexibleDecimal
}

struct CurrentUserDTO: Decodable {
    var id: String?
    var email: String?
    var token: String?
    var currency: String?
    var cookieHeader: String?
    var appVersion: String?
    var balanceAlert: BalanceAlertDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case token
        case currency
        case cookieHeader = "cookie_header"
        case appVersion = "app_version"
        case balanceAlert = "balance_alert"
    }
}

struct BalanceAlertDTO: Decodable {
    var cny: CurrencyAlertDTO?
    var usd: CurrencyAlertDTO?

    enum CodingKeys: String, CodingKey {
        case cny = "CNY"
        case usd = "USD"
    }
}

struct CurrencyAlertDTO: Decodable {
    var enabled: Bool?
    var alertBound: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case alertBound = "alert_bound"
    }
}

struct FlexibleDecimal: Decodable, Equatable, Sendable {
    var value: Decimal

    init(_ value: Decimal) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = Decimal(string: string) ?? 0
            return
        }
        if let double = try? container.decode(Double.self) {
            value = Decimal(double)
            return
        }
        if let int = try? container.decode(Int.self) {
            value = Decimal(int)
            return
        }
        value = 0
    }
}

struct FlexibleInt: Decodable, Equatable, Sendable {
    var value: Int

    init(_ value: Int) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = Int(string) ?? NSDecimalNumber(decimal: Decimal(string: string) ?? 0).intValue
            return
        }
        if let int = try? container.decode(Int.self) {
            value = int
            return
        }
        if let double = try? container.decode(Double.self) {
            value = Int(double)
            return
        }
        value = 0
    }
}
