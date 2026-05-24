import Foundation
import Testing
@testable import DeepSeekMonitor

@Suite("DeepSeek decoding and alerts")
struct DeepSeekMonitorTests {
    @Test func decodesUserSummary() throws {
        let data = try fixture("user_summary")
        let envelope = try JSONDecoder().decode(APIEnvelope<UserSummaryDTO>.self, from: data)
        let summary = DeepSeekClient.mapSummary(try #require(envelope.data?.bizData))

        #expect(summary.currency == "CNY")
        #expect(summary.estimatedAvailableTokens == 78_362_045)
        #expect(summary.monthlyTokenUsage == 40_604_483)
        #expect(NSDecimalNumber(decimal: summary.balance).doubleValue > 235)
    }

    @Test func decodesUsageAmount() throws {
        let data = try fixture("usage_amount")
        let envelope = try JSONDecoder().decode(APIEnvelope<UsageDTO>.self, from: data)
        let dto = try #require(envelope.data?.bizData)
        let usage = UsageBreakdown(
            month: 5,
            year: 2026,
            modelTotals: DeepSeekClient.mapModels(dto.total),
            dailyTotals: DeepSeekClient.mapDays(dto.days)
        )

        #expect(usage.modelTotals.count == 2)
        #expect(usage.dailyTotals.count == 2)
        #expect(usage.modelTotals[0].amount(for: .request) == 607)
    }

    @Test func aggregatesRequestsAndTokensSeparately() throws {
        let data = try fixture("usage_amount")
        let envelope = try JSONDecoder().decode(APIEnvelope<UsageDTO>.self, from: data)
        let dto = try #require(envelope.data?.bizData)
        let models = DeepSeekClient.mapModels(dto.total)

        #expect(models.requestCount == 608)
        #expect(models.tokenTotal == 40_604_483)
        #expect(models.tokenTotal == models.amount(for: .promptCacheHitToken) + models.amount(for: .promptCacheMissToken) + models.amount(for: .responseToken))
    }

    @Test func usageTypeChineseTitles() {
        #expect(UsageType.request.title(language: .simplifiedChinese) == "API 请求数")
        #expect(UsageType.promptCacheHitToken.title(language: .simplifiedChinese) == "缓存命中")
        #expect(UsageType.promptCacheMissToken.title(language: .simplifiedChinese) == "缓存未命中")
        #expect(UsageType.responseToken.title(language: .simplifiedChinese) == "响应 Token")
    }

    @Test func tokenFormatterDoesNotAbbreviateLargeValues() {
        #expect(Formatters.compactNumber(27_784_704) == "27,784,704")
        #expect(Formatters.compactDecimal(Decimal(3_400_000_000)) == "3,400,000,000")
    }

    @Test func usageBreakdownFindsTodayMetric() {
        let today = DailyMetric(date: Date(), models: [
            ModelMetric(model: "deepseek-v4-pro", metrics: [
                MetricValue(type: .promptCacheHitToken, amount: 10),
                MetricValue(type: .responseToken, amount: 2)
            ])
        ])
        let yesterday = DailyMetric(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, models: [])
        let usage = UsageBreakdown(month: 5, year: 2026, modelTotals: [], dailyTotals: [yesterday, today])

        #expect(usage.today?.tokenTotal == 12)
    }

    @Test func decodesUsageCostArrayPayload() throws {
        let data = try fixture("usage_cost")
        let envelope = try JSONDecoder().decode(APIEnvelope<[CostDTO]>.self, from: data)
        let dto = try #require(envelope.data?.bizData?.first)

        #expect(dto.currency == "CNY")
        #expect(dto.total.count == 1)
        #expect(DeepSeekClient.mapModels(dto.total)[0].total > 10)
    }

    @Test func credentialStoreRoundTripsInMemory() throws {
        let store = InMemoryCredentialStore()
        #expect(try store.loadToken() == nil)
        try store.saveToken("abc123")
        #expect(try store.loadToken() == "abc123")
        try store.deleteToken()
        #expect(try store.loadToken() == nil)
    }

    @Test func alertsDeduplicateUntilRecovery() throws {
        let evaluator = AlertEvaluator()
        let snapshot = MonitorSnapshot(
            account: AccountSummary(
                balance: 10,
                bonusBalance: 0,
                currency: "CNY",
                estimatedAvailableTokens: 1_000,
                monthlyCost: 200,
                monthlyTokenUsage: 200_000_000,
                currentToken: 0
            ),
            usage: .empty,
            costs: .empty,
            refreshedAt: Date()
        )
        let rule = AlertRule.defaults

        let first = evaluator.evaluate(snapshot: snapshot, rule: rule, activeKeys: [])
        #expect(first.0.count == 3)

        let second = evaluator.evaluate(snapshot: snapshot, rule: rule, activeKeys: first.1)
        #expect(second.0.isEmpty)
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
