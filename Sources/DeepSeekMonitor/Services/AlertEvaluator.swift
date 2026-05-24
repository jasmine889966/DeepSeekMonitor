import Foundation

struct AlertEvaluator: Sendable {
    func evaluate(snapshot: MonitorSnapshot, rule: AlertRule, activeKeys: Set<String>) -> ([AlertEvent], Set<String>) {
        var nextKeys = Set<String>()
        var events: [AlertEvent] = []

        checkDecimal(
            key: "balance:\(rule.balanceThreshold)",
            isActive: snapshot.account.balance < rule.balanceThreshold,
            title: "Low DeepSeek balance",
            detail: "Balance is \(Formatters.money(snapshot.account.balance, currency: snapshot.account.currency)).",
            activeKeys: activeKeys,
            nextKeys: &nextKeys,
            events: &events
        )

        checkDecimal(
            key: "monthlyCost:\(rule.monthlyCostThreshold)",
            isActive: snapshot.account.monthlyCost >= rule.monthlyCostThreshold,
            title: "Monthly cost threshold reached",
            detail: "This month is \(Formatters.money(snapshot.account.monthlyCost, currency: snapshot.account.currency)).",
            activeKeys: activeKeys,
            nextKeys: &nextKeys,
            events: &events
        )

        let tokenKey = "monthlyTokens:\(rule.monthlyTokenThreshold)"
        if snapshot.account.monthlyTokenUsage >= rule.monthlyTokenThreshold {
            nextKeys.insert(tokenKey)
            if !activeKeys.contains(tokenKey) {
                events.append(AlertEvent(
                    id: UUID().uuidString,
                    title: "Monthly token threshold reached",
                    detail: "Usage is \(Formatters.compactNumber(snapshot.account.monthlyTokenUsage)) tokens.",
                    date: Date()
                ))
            }
        }

        return (events, nextKeys)
    }

    private func checkDecimal(
        key: String,
        isActive: Bool,
        title: String,
        detail: String,
        activeKeys: Set<String>,
        nextKeys: inout Set<String>,
        events: inout [AlertEvent]
    ) {
        guard isActive else { return }
        nextKeys.insert(key)
        guard !activeKeys.contains(key) else { return }
        events.append(AlertEvent(id: UUID().uuidString, title: title, detail: detail, date: Date()))
    }
}
