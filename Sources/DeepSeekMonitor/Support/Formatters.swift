import Foundation

enum Formatters {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let shortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static func money(_ value: Decimal, currency: String = "CNY") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = value < 1 ? 4 : 2
        formatter.minimumFractionDigits = 2
        if currency == "CNY" {
            formatter.currencySymbol = "¥"
        }
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    static func compactNumber(_ value: Int) -> String {
        decimal(Decimal(value), fractionDigits: 0)
    }

    static func compactDecimal(_ value: Decimal) -> String {
        decimal(value, fractionDigits: 0)
    }

    static func abbreviatedDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        if value >= 1_000_000 {
            return "\(formatter.string(from: NSNumber(value: doubleValue / 1_000_000)) ?? "0")M"
        }
        if value >= 1_000 {
            return "\(formatter.string(from: NSNumber(value: doubleValue / 1_000)) ?? "0")K"
        }
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    static func decimal(_ value: Decimal, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    static func plainDecimal(_ value: Decimal, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}

extension Decimal {
    static func < (lhs: Decimal, rhs: Decimal) -> Bool {
        NSDecimalNumber(decimal: lhs).compare(NSDecimalNumber(decimal: rhs)) == .orderedAscending
    }

    static func >= (lhs: Decimal, rhs: Decimal) -> Bool {
        NSDecimalNumber(decimal: lhs).compare(NSDecimalNumber(decimal: rhs)) != .orderedAscending
    }
}
