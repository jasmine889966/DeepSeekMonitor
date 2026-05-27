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

    @Test func costBreakdownFindsTodayMetric() {
        let today = DailyMetric(date: Date(), models: [
            ModelMetric(model: "deepseek-v4-pro", metrics: [
                MetricValue(type: .promptCacheHitToken, amount: Decimal(string: "0.12")!),
                MetricValue(type: .promptCacheMissToken, amount: Decimal(string: "0.34")!),
                MetricValue(type: .responseToken, amount: Decimal(string: "0.56")!)
            ])
        ])
        let yesterday = DailyMetric(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, models: [])
        let costs = CostBreakdown(month: 5, year: 2026, currency: "CNY", modelTotals: [], dailyTotals: [yesterday, today])

        #expect(costs.today?.total == Decimal(string: "1.02")!)
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

    @Test func parsesOfficialStatusPageComponents() throws {
        let html = String(data: try fixture("status_page", extension: "html"), encoding: .utf8)!
        let atom = try fixture("status_history", extension: "atom")
        let incidents = try OfficialStatusParser.parseAtom(data: atom)
        let status = try OfficialStatusParser.parseStatusPage(html: html, incidents: incidents)

        #expect(status.components.count == 2)
        #expect(status.components[0].name == "API 服务 (API Service)")
        #expect(status.components[0].uptime == "99.90% uptime")
        #expect(status.components[0].days.map(\.health) == [.operational, .degraded, .outage])
        #expect(status.components[1].days[1].health == .degraded)
    }

    @Test func parsesOfficialStatusAtomIncidentsNewestFirst() throws {
        let atom = try fixture("status_history", extension: "atom")
        let incidents = try OfficialStatusParser.parseAtom(data: atom)

        #expect(incidents.count == 2)
        #expect(incidents[0].id == "urn:flashduty:change:6480608319287")
        #expect(incidents[0].status == "resolved")
        #expect(incidents[0].affectedComponents == ["API 服务 (API Service)", "网页对话服务 (Web Chat Service)"])
        #expect(incidents[0].link?.absoluteString == "https://status.deepseek.com/incidents/6480608319287")
    }

    @MainActor
    @Test func officialStatusRefreshFailureKeepsPreviousStatus() async throws {
        let previous = OfficialServiceStatus(
            summary: .operational,
            summaryTitle: "Everything is running smoothly",
            summaryDetail: "All systems are operating as expected.",
            components: [
                ServiceComponentStatus(
                    name: "API 服务 (API Service)",
                    uptime: "99.90% uptime",
                    currentHealth: .operational,
                    days: []
                )
            ],
            incidents: [],
            sourceURL: OfficialServiceStatus.sourceURL,
            refreshedAt: Date()
        )
        let store = MonitorStore(
            credentialStore: InMemoryCredentialStore(),
            client: FailingDeepSeekClient(),
            officialStatusClient: FailingOfficialStatusClient(),
            notifier: NoopNotifier()
        )
        store.officialStatus = previous

        await store.refreshNow()

        #expect(store.officialStatus == previous)
        #expect(store.officialStatusErrorMessage != nil)
        #expect(store.authState == .unauthenticated)
    }

    private func fixture(_ name: String, extension fileExtension: String = "json") throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: fileExtension))
        return try Data(contentsOf: url)
    }
}

private struct FailingOfficialStatusClient: OfficialStatusFetching {
    func fetchStatus() async throws -> OfficialServiceStatus {
        throw OfficialStatusError.noComponents
    }
}

private struct FailingDeepSeekClient: DeepSeekFetching {
    func validateCurrentUser(session: DeepSeekSession) async throws -> CurrentUserDTO { throw DeepSeekClientError.missingToken }
    func fetchClientSettings(session: DeepSeekSession, scope: String) async throws {}
    func fetchClientSettings(session: DeepSeekSession, did: String) async throws {}
    func fetchSummary(session: DeepSeekSession) async throws -> AccountSummary { throw DeepSeekClientError.missingToken }
    func fetchUsage(session: DeepSeekSession, month: Int, year: Int) async throws -> UsageBreakdown { throw DeepSeekClientError.missingToken }
    func fetchCosts(session: DeepSeekSession, month: Int, year: Int) async throws -> CostBreakdown { throw DeepSeekClientError.missingToken }
}

private struct NoopNotifier: UserNotifying {
    func requestAuthorization() async {}
    func notify(title: String, body: String) async {}
}
