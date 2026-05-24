import Foundation
import os

enum DeepSeekClientError: LocalizedError, Equatable {
    case missingToken
    case unauthorized
    case unexpectedStatus(Int)
    case apiMessage(String)
    case changedInterface(String)

    var errorDescription: String? {
        switch self {
        case .missingToken: "Please log in to DeepSeek first."
        case .unauthorized: "The DeepSeek session expired. Please log in again."
        case .unexpectedStatus(let status): "DeepSeek returned HTTP \(status)."
        case .apiMessage(let message): message.isEmpty ? "DeepSeek returned an API error." : message
        case .changedInterface(let message): "DeepSeek interface changed: \(message)"
        }
    }
}

protocol DeepSeekFetching: Sendable {
    func validateCurrentUser(session: DeepSeekSession) async throws -> CurrentUserDTO
    func fetchClientSettings(session: DeepSeekSession, scope: String) async throws
    func fetchClientSettings(session: DeepSeekSession, did: String) async throws
    func fetchSummary(session: DeepSeekSession) async throws -> AccountSummary
    func fetchUsage(session: DeepSeekSession, month: Int, year: Int) async throws -> UsageBreakdown
    func fetchCosts(session: DeepSeekSession, month: Int, year: Int) async throws -> CostBreakdown
}

struct DeepSeekSession: Sendable, Equatable {
    var token: String
    var cookieHeader: String
    var appVersion: String = "1.0.0"
    var acceptLanguage: String = "zh-CN,zh-Hans;q=0.9"
    var did: String = ""

    var userAgent: String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Mobile/15E148 Safari/604.1"
    }

    var referer: String {
        "https://platform.deepseek.com/usage"
    }
}

struct DeepSeekClient: DeepSeekFetching {
    var baseURL = URL(string: "https://platform.deepseek.com")!
    var urlSession: URLSession = .shared
    var decoder = JSONDecoder()

    func validateCurrentUser(session: DeepSeekSession) async throws -> CurrentUserDTO {
        MonitorLogger.client.info("request current user")
        return try await request(
            path: "/auth-api/v0/users/current",
            session: session,
            decode: CurrentUserDTO.self
        )
    }

    func fetchClientSettings(session: DeepSeekSession, scope: String) async throws {
        MonitorLogger.client.info("request client settings scope=\(scope, privacy: .public)")
        _ = try await rawRequest(
            path: "/api/v0/client/settings",
            queryItems: [URLQueryItem(name: "scope", value: scope)],
            session: session,
            includeAuth: false,
            includeFetchDest: false
        )
    }

    func fetchClientSettings(session: DeepSeekSession, did: String) async throws {
        MonitorLogger.client.info("request client settings did")
        _ = try await rawRequest(
            path: "/api/v0/client/settings",
            queryItems: [URLQueryItem(name: "did", value: did)],
            session: session,
            includeAuth: true,
            includeFetchDest: true
        )
    }

    func fetchSummary(session: DeepSeekSession) async throws -> AccountSummary {
        MonitorLogger.client.info("request summary")
        let dto = try await request(
            path: "/api/v0/users/get_user_summary",
            session: session,
            decode: UserSummaryDTO.self
        )
        return Self.mapSummary(dto)
    }

    func fetchUsage(session: DeepSeekSession, month: Int, year: Int) async throws -> UsageBreakdown {
        MonitorLogger.client.info("request usage month=\(month), year=\(year)")
        let dto = try await request(
            path: "/api/v0/usage/amount",
            queryItems: [
                URLQueryItem(name: "month", value: "\(month)"),
                URLQueryItem(name: "year", value: "\(year)")
            ],
            session: session,
            decode: UsageDTO.self
        )
        return UsageBreakdown(
            month: month,
            year: year,
            modelTotals: Self.mapModels(dto.total),
            dailyTotals: Self.mapDays(dto.days)
        )
    }

    func fetchCosts(session: DeepSeekSession, month: Int, year: Int) async throws -> CostBreakdown {
        MonitorLogger.client.info("request costs month=\(month), year=\(year)")
        let dtos = try await request(
            path: "/api/v0/usage/cost",
            queryItems: [
                URLQueryItem(name: "month", value: "\(month)"),
                URLQueryItem(name: "year", value: "\(year)")
            ],
            session: session,
            decode: [CostDTO].self
        )
        let dto = dtos.first ?? CostDTO(total: [], days: [], currency: "CNY")
        return CostBreakdown(
            month: month,
            year: year,
            currency: dto.currency ?? "CNY",
            modelTotals: Self.mapModels(dto.total),
            dailyTotals: Self.mapDays(dto.days)
        )
    }

    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        session: DeepSeekSession,
        decode type: T.Type
    ) async throws -> T {
        let (data, _) = try await rawRequest(
            path: path,
            queryItems: queryItems,
            session: session,
            includeAuth: true,
            includeFetchDest: true
        )
        let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
        guard envelope.code == 0 else {
            MonitorLogger.client.error("api code nonzero path=\(path, privacy: .public) msg=\(envelope.msg, privacy: .public)")
            if Self.isUnauthorizedMessage(envelope.msg) {
                throw DeepSeekClientError.unauthorized
            }
            throw DeepSeekClientError.apiMessage(envelope.msg)
        }
        guard let business = envelope.data else {
            MonitorLogger.client.error("missing business envelope path=\(path, privacy: .public)")
            throw DeepSeekClientError.changedInterface("Missing data envelope.")
        }
        if let bizCode = business.bizCode, bizCode != 0 {
            MonitorLogger.client.error("business code nonzero path=\(path, privacy: .public) msg=\(business.bizMsg ?? "", privacy: .public)")
            if Self.isUnauthorizedMessage(business.bizMsg ?? "") {
                throw DeepSeekClientError.unauthorized
            }
            throw DeepSeekClientError.apiMessage(business.bizMsg ?? "")
        }
        guard let payload = business.bizData else {
            MonitorLogger.client.error("missing biz data path=\(path, privacy: .public)")
            throw DeepSeekClientError.changedInterface("Missing biz_data payload.")
        }
        return payload
    }

    private func rawRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        session: DeepSeekSession,
        includeAuth: Bool,
        includeFetchDest: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        if includeAuth && session.token.isEmpty {
            MonitorLogger.client.error("missing token path=\(path, privacy: .public)")
            throw DeepSeekClientError.missingToken
        }
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw DeepSeekClientError.changedInterface("Invalid URL for \(path).")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        if includeFetchDest {
            request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        }
        request.setValue(session.appVersion, forHTTPHeaderField: "x-app-version")
        request.setValue(session.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(session.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(session.referer, forHTTPHeaderField: "Referer")
        request.setValue("u=3, i", forHTTPHeaderField: "Priority")
        request.setValue("gzip, deflate, br, zstd", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        if includeAuth {
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        }
        if !session.cookieHeader.isEmpty {
            request.setValue(session.cookieHeader, forHTTPHeaderField: "Cookie")
        }
        MonitorLogger.client.info("request prepared path=\(path, privacy: .public) auth=\(includeAuth ? "yes" : "no", privacy: .public)")
        MonitorLogger.file("client", "request prepared path=\(path) auth=\(includeAuth ? "yes" : "no")")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            MonitorLogger.client.error("missing http response path=\(path, privacy: .public)")
            MonitorLogger.file("client", "missing http response path=\(path)")
            throw DeepSeekClientError.changedInterface("Missing HTTP response.")
        }
        MonitorLogger.client.info("response status path=\(path, privacy: .public) status=\(http.statusCode)")
        MonitorLogger.file("client", "response status path=\(path) status=\(http.statusCode)")
        if http.statusCode == 401 || http.statusCode == 403 {
            throw DeepSeekClientError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            MonitorLogger.client.error("unexpected status path=\(path, privacy: .public) status=\(http.statusCode)")
            MonitorLogger.file("client", "unexpected status path=\(path) status=\(http.statusCode)")
            throw DeepSeekClientError.unexpectedStatus(http.statusCode)
        }
        if let did = session.did.isEmpty ? nil : session.did, path == "/auth-api/v0/users/current" {
            _ = did
        }
        return (data, http)
    }

    static func mapSummary(_ dto: UserSummaryDTO) -> AccountSummary {
        let normal = dto.normalWallets.first
        let bonus = dto.bonusWallets.first
        let cost = dto.monthlyCosts.first
        return AccountSummary(
            balance: normal?.balance.value ?? 0,
            bonusBalance: bonus?.balance.value ?? 0,
            currency: normal?.currency ?? cost?.currency ?? "CNY",
            estimatedAvailableTokens: dto.totalAvailableTokenEstimation?.value ?? normal?.tokenEstimation?.value ?? 0,
            monthlyCost: cost?.amount.value ?? 0,
            monthlyTokenUsage: dto.monthlyTokenUsage?.value ?? dto.monthlyUsage?.value ?? 0,
            currentToken: dto.currentToken?.value ?? 0
        )
    }

    static func mapModels(_ dtos: [ModelUsageDTO]) -> [ModelMetric] {
        dtos.map { dto in
            ModelMetric(
                model: dto.model,
                metrics: dto.usage.map {
                    MetricValue(type: UsageType(rawAPIValue: $0.type), amount: $0.amount.value)
                }
            )
        }
    }

    static func mapDays(_ dtos: [DailyUsageDTO]) -> [DailyMetric] {
        dtos.compactMap { dto in
            guard let date = Formatters.day.date(from: dto.date) else {
                return nil
            }
            return DailyMetric(date: date, models: mapModels(dto.data))
        }
    }

    private static func isUnauthorizedMessage(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("authorization failed")
            || lower.contains("invalid token")
            || lower.contains("token expired")
            || lower.contains("unauthorized")
    }
}

struct MockDeepSeekClient: DeepSeekFetching {
    func fetchClientSettings(session: DeepSeekSession, scope: String) async throws {}

    func fetchClientSettings(session: DeepSeekSession, did: String) async throws {}

    var summary: AccountSummary = AccountSummary(
        balance: 235.086136,
        bonusBalance: 0,
        currency: "CNY",
        estimatedAvailableTokens: 78_362_045,
        monthlyCost: 10.169033,
        monthlyTokenUsage: 40_604_483,
        currentToken: 10_000_000
    )

    func validateCurrentUser(session: DeepSeekSession) async throws -> CurrentUserDTO {
        CurrentUserDTO(id: "mock", email: "mock@deepseek.local", token: session.token, currency: "CNY", cookieHeader: session.cookieHeader, appVersion: session.appVersion)
    }

    func fetchSummary(session: DeepSeekSession) async throws -> AccountSummary {
        summary
    }

    func fetchUsage(session: DeepSeekSession, month: Int, year: Int) async throws -> UsageBreakdown {
        UsageBreakdown(
            month: month,
            year: year,
            modelTotals: [
                ModelMetric(model: "deepseek-v4-pro", metrics: [
                    MetricValue(type: .promptCacheHitToken, amount: 37_849_600),
                    MetricValue(type: .promptCacheMissToken, amount: 2_435_492),
                    MetricValue(type: .responseToken, amount: 319_385),
                    MetricValue(type: .request, amount: 607)
                ])
            ],
            dailyTotals: [
                DailyMetric(date: Date(), models: [
                    ModelMetric(model: "deepseek-v4-pro", metrics: [
                        MetricValue(type: .promptCacheHitToken, amount: 14_208_384),
                        MetricValue(type: .promptCacheMissToken, amount: 624_707),
                        MetricValue(type: .responseToken, amount: 158_235),
                        MetricValue(type: .request, amount: 319)
                    ])
                ])
            ]
        )
    }

    func fetchCosts(session: DeepSeekSession, month: Int, year: Int) async throws -> CostBreakdown {
        CostBreakdown(
            month: month,
            year: year,
            currency: "CNY",
            modelTotals: [
                ModelMetric(model: "deepseek-v4-pro", metrics: [
                    MetricValue(type: .promptCacheHitToken, amount: 0.94624),
                    MetricValue(type: .promptCacheMissToken, amount: 7.306476),
                    MetricValue(type: .responseToken, amount: 1.91631)
                ])
            ],
            dailyTotals: [
                DailyMetric(date: Date(), models: [
                    ModelMetric(model: "deepseek-v4-pro", metrics: [
                        MetricValue(type: .promptCacheHitToken, amount: 0.3552096),
                        MetricValue(type: .promptCacheMissToken, amount: 1.874121),
                        MetricValue(type: .responseToken, amount: 0.94941)
                    ])
                ])
            ]
        )
    }
}
