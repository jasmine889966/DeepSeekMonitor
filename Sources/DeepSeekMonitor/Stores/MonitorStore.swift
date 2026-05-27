import Foundation
import Observation
import SwiftUI
import os

@MainActor
@Observable
final class MonitorStore {
    enum AuthState: Equatable {
        case unknown
        case unauthenticated
        case authenticated
        case expired
    }

    private let credentialStore: CredentialStoring
    private let client: DeepSeekFetching
    private let officialStatusClient: OfficialStatusFetching
    private let notifier: UserNotifying
    private let alertEvaluator = AlertEvaluator()
    private var currentSession: DeepSeekSession?

    private enum DefaultsKey {
        static let balanceThreshold = "balanceThreshold"
        static let monthlyCostThreshold = "monthlyCostThreshold"
        static let monthlyTokenThreshold = "monthlyTokenThreshold"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let appLanguage = "appLanguage"
    }

    var authState: AuthState = .unknown
    var snapshot: MonitorSnapshot?
    var alerts: [AlertEvent] = []
    var selectedSection: MonitorSection = .overview
    var isRefreshing = false
    var errorMessage: String?
    var officialStatus: OfficialServiceStatus?
    var officialStatusErrorMessage: String?
    var officialStatusRefreshedAt: Date?
    var lastTokenPreview: String?

    private var balanceThresholdString: String
    private var monthlyCostThresholdString: String
    private var monthlyTokenThreshold: Int
    private var refreshIntervalMinutes: Int
    private var appLanguageRaw: String

    @ObservationIgnored
    private var refreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeAlertKeys = Set<String>()

    init(
        credentialStore: CredentialStoring = CredentialStore(),
        client: DeepSeekFetching = DeepSeekClient(),
        officialStatusClient: OfficialStatusFetching = OfficialStatusClient(),
        notifier: UserNotifying = NotificationService()
    ) {
        self.credentialStore = credentialStore
        self.client = client
        self.officialStatusClient = officialStatusClient
        self.notifier = notifier
        let defaults = UserDefaults.standard
        balanceThresholdString = defaults.string(forKey: DefaultsKey.balanceThreshold) ?? "50"
        monthlyCostThresholdString = defaults.string(forKey: DefaultsKey.monthlyCostThreshold) ?? "100"
        let savedMonthlyTokenThreshold = defaults.integer(forKey: DefaultsKey.monthlyTokenThreshold)
        monthlyTokenThreshold = savedMonthlyTokenThreshold == 0 ? 100_000_000 : savedMonthlyTokenThreshold
        let savedRefreshInterval = defaults.integer(forKey: DefaultsKey.refreshIntervalMinutes)
        refreshIntervalMinutes = savedRefreshInterval == 0 ? 15 : savedRefreshInterval
        appLanguageRaw = defaults.string(forKey: DefaultsKey.appLanguage) ?? AppLanguage.simplifiedChinese.rawValue
    }

    var rule: AlertRule {
        AlertRule(
            balanceThreshold: Decimal(string: balanceThresholdString) ?? AlertRule.defaults.balanceThreshold,
            monthlyCostThreshold: Decimal(string: monthlyCostThresholdString) ?? AlertRule.defaults.monthlyCostThreshold,
            monthlyTokenThreshold: monthlyTokenThreshold,
            refreshIntervalMinutes: max(1, refreshIntervalMinutes)
        )
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: appLanguageRaw) ?? .english }
        set {
            appLanguageRaw = newValue.rawValue
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKey.appLanguage)
            if var session = currentSession {
                session.acceptLanguage = newValue.isChinese ? "zh-CN,zh-Hans;q=0.9" : "en-US,en;q=0.9"
                currentSession = session
            }
        }
    }

    var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { self.language },
            set: { self.language = $0 }
        )
    }

    var alertProgress: Double {
        let threshold = NSDecimalNumber(decimal: rule.balanceThreshold).doubleValue
        guard threshold > 0, let balance = snapshot?.account.balance else { return 0 }
        let ratio = NSDecimalNumber(decimal: balance).doubleValue / threshold
        return max(0, min(1, 1 - ratio))
    }

    var iconTone: AppIconTone {
        let progress = alertProgress
        if progress >= 0.9 {
            return .danger
        } else if progress >= 0.7 {
            return .warning
        } else if progress > 0 {
            return .normal
        } else {
            return .muted
        }
    }

    var statusBarIconTone: AppIconTone {
        guard let summary = officialStatus?.summary else { return .muted }
        return summary == .operational ? .menuBarNormal : .danger
    }

    var menuBarStatusTitle: String {
        officialStatus?.summary.title(language: language) ?? l10n.notConnected
    }

    var l10n: L10n {
        L10n(language: language)
    }

    var balanceThreshold: String {
        get { balanceThresholdString }
        set {
            balanceThresholdString = newValue
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.balanceThreshold)
        }
    }

    var balanceThresholdValue: Double {
        get { NSDecimalNumber(decimal: Decimal(string: balanceThresholdString) ?? AlertRule.defaults.balanceThreshold).doubleValue }
        set { balanceThresholdString = Formatters.plainDecimal(Decimal(newValue)) }
    }

    var monthlyCostThreshold: String {
        get { monthlyCostThresholdString }
        set {
            monthlyCostThresholdString = newValue
            UserDefaults.standard.set(newValue, forKey: DefaultsKey.monthlyCostThreshold)
        }
    }

    var monthlyCostThresholdValue: Double {
        get { NSDecimalNumber(decimal: Decimal(string: monthlyCostThresholdString) ?? AlertRule.defaults.monthlyCostThreshold).doubleValue }
        set { monthlyCostThresholdString = Formatters.plainDecimal(Decimal(newValue)) }
    }

    var monthlyTokenLimit: Int {
        get { monthlyTokenThreshold }
        set {
            monthlyTokenThreshold = max(1, newValue)
            UserDefaults.standard.set(monthlyTokenThreshold, forKey: DefaultsKey.monthlyTokenThreshold)
        }
    }

    var refreshMinutes: Int {
        get { refreshIntervalMinutes }
        set {
            refreshIntervalMinutes = max(1, newValue)
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: DefaultsKey.refreshIntervalMinutes)
            scheduleRefresh()
        }
    }

    func start() async {
        MonitorLogger.store.info("start")
        MonitorLogger.file("store", "start")
        await notifier.requestAuthorization()
        do {
            if let token = try credentialStore.loadToken() {
                let cookieHeader = try credentialStore.loadCookieHeader() ?? ""
                currentSession = DeepSeekSession(
                    token: token,
                    cookieHeader: cookieHeader,
                    acceptLanguage: language.isChinese ? "zh-CN,zh-Hans;q=0.9" : "en-US,en;q=0.9",
                    did: UserDefaults.standard.string(forKey: "deepseek.device-id") ?? ""
                )
                lastTokenPreview = tokenPreview(token)
                authState = .authenticated
                MonitorLogger.store.info("loaded credentials from local config")
                MonitorLogger.file("store", "loaded credentials from local config")
                await refreshNow()
            } else {
                authState = .unauthenticated
                MonitorLogger.store.info("no saved credentials")
                MonitorLogger.file("store", "no saved credentials")
            }
        } catch {
            errorMessage = error.localizedDescription
            authState = .unauthenticated
            MonitorLogger.store.error("start failed: \(error.localizedDescription, privacy: .public)")
            MonitorLogger.file("store", "start failed: \(error.localizedDescription)")
        }
        scheduleRefresh()
    }

    func saveSessionFromLogin(_ session: DeepSeekSession) async {
        MonitorLogger.login.info("captured login session")
        MonitorLogger.file("login", "captured login session")
        do {
            _ = try await client.validateCurrentUser(session: session)
            try credentialStore.saveToken(session.token)
            try credentialStore.saveCookieHeader(session.cookieHeader)
            currentSession = session
            lastTokenPreview = tokenPreview(session.token)
            authState = .authenticated
            errorMessage = nil
            MonitorLogger.store.info("saved session to local config")
            MonitorLogger.file("store", "saved session to local config")
            await refreshNow()
            updateAppIcon()
        } catch DeepSeekClientError.unauthorized {
            authState = .unauthenticated
            errorMessage = DeepSeekClientError.unauthorized.localizedDescription
            MonitorLogger.login.error("validation unauthorized")
            MonitorLogger.file("login", "validation unauthorized")
            updateAppIcon()
        } catch {
            errorMessage = error.localizedDescription
            MonitorLogger.login.error("login save failed: \(error.localizedDescription, privacy: .public)")
            MonitorLogger.file("login", "login save failed: \(error.localizedDescription)")
        }
    }

    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let officialStatusTask = Task { try await officialStatusClient.fetchStatus() }
        MonitorLogger.store.info("refresh begin")
        MonitorLogger.file("store", "refresh begin")

        do {
            guard let token = try credentialStore.loadToken(), !token.isEmpty else {
                authState = .unauthenticated
                snapshot = nil
                MonitorLogger.store.info("refresh skipped, no token")
                MonitorLogger.file("store", "refresh skipped, no token")
                await finishOfficialStatusRefresh(officialStatusTask)
                return
            }
            let cookieHeader = try credentialStore.loadCookieHeader() ?? ""
            let session = currentSession ?? DeepSeekSession(
                token: token,
                cookieHeader: cookieHeader,
                acceptLanguage: language.isChinese ? "zh-CN,zh-Hans;q=0.9" : "en-US,en;q=0.9",
                did: UserDefaults.standard.string(forKey: "deepseek.device-id") ?? ""
            )
            currentSession = session
            let calendar = Calendar.current
            let now = Date()
            let month = calendar.component(.month, from: now)
            let year = calendar.component(.year, from: now)
            MonitorLogger.client.info("refresh session prepared, month=\(month), year=\(year)")
            MonitorLogger.file("client", "refresh session prepared month=\(month) year=\(year)")

            async let bannerSettings = client.fetchClientSettings(session: session, scope: "banner")
            async let currentUser = client.validateCurrentUser(session: session)
            async let summary = client.fetchSummary(session: session)
            async let usage = client.fetchUsage(session: session, month: month, year: year)
            async let costs = client.fetchCosts(session: session, month: month, year: year)

            _ = try await bannerSettings
            MonitorLogger.client.info("banner settings loaded")
            MonitorLogger.file("client", "banner settings loaded")
            let current = try await currentUser
            MonitorLogger.client.info("current user loaded")
            MonitorLogger.file("client", "current user loaded")
            let newSnapshot = try await MonitorSnapshot(
                account: summary,
                usage: usage,
                costs: costs,
                refreshedAt: now
            )
            MonitorLogger.client.info("snapshot built")
            MonitorLogger.file("client", "snapshot built balance=\(newSnapshot.account.balance) usageDays=\(newSnapshot.usage.dailyTotals.count) costDays=\(newSnapshot.costs.dailyTotals.count)")
            if let did = session.did.isEmpty ? nil : session.did {
                try? await client.fetchClientSettings(session: session, did: did)
            }
            if let returnedToken = current.token, !returnedToken.isEmpty, returnedToken != session.token {
                currentSession?.token = returnedToken
                try credentialStore.saveToken(returnedToken)
            }
            if let returnedCookie = current.cookieHeader, !returnedCookie.isEmpty {
                currentSession?.cookieHeader = returnedCookie
                try credentialStore.saveCookieHeader(returnedCookie)
            }
            if let alert = current.balanceAlert?.cny?.alertBound, let balanceThreshold = Decimal(string: alert) {
                balanceThresholdString = NSDecimalNumber(decimal: balanceThreshold).stringValue
            }
            snapshot = newSnapshot
            authState = .authenticated
            errorMessage = nil
            processAlerts(for: newSnapshot)
            updateAppIcon()
        } catch DeepSeekClientError.unauthorized {
            authState = .expired
            errorMessage = DeepSeekClientError.unauthorized.localizedDescription
            MonitorLogger.store.error("refresh unauthorized")
            MonitorLogger.file("store", "refresh unauthorized")
            updateAppIcon()
        } catch {
            errorMessage = error.localizedDescription
            MonitorLogger.store.error("refresh failed: \(error.localizedDescription, privacy: .public)")
            MonitorLogger.file("store", "refresh failed: \(error.localizedDescription)")
        }
        await finishOfficialStatusRefresh(officialStatusTask)
    }

    func logout() {
        do {
            try credentialStore.deleteToken()
            try credentialStore.deleteCookieHeader()
            snapshot = nil
            lastTokenPreview = nil
            authState = .unauthenticated
            errorMessage = nil
            activeAlertKeys.removeAll()
            MonitorLogger.store.info("logout completed")
            MonitorLogger.file("store", "logout completed")
            updateAppIcon()
        } catch {
            errorMessage = error.localizedDescription
            MonitorLogger.store.error("logout failed: \(error.localizedDescription, privacy: .public)")
            MonitorLogger.file("store", "logout failed: \(error.localizedDescription)")
        }
    }

    func clearAlerts() {
        alerts.removeAll()
    }

    private func finishOfficialStatusRefresh(_ task: Task<OfficialServiceStatus, Error>) async {
        do {
            let status = try await task.value
            officialStatus = status
            officialStatusRefreshedAt = status.refreshedAt
            officialStatusErrorMessage = nil
            updateAppIcon()
            MonitorLogger.store.info("official status loaded")
            MonitorLogger.file("store", "official status loaded components=\(status.components.count) incidents=\(status.incidents.count)")
        } catch {
            officialStatusErrorMessage = error.localizedDescription
            MonitorLogger.store.error("official status failed: \(error.localizedDescription, privacy: .public)")
            MonitorLogger.file("store", "official status failed: \(error.localizedDescription)")
        }
    }

    private func processAlerts(for snapshot: MonitorSnapshot) {
        let (events, nextKeys) = alertEvaluator.evaluate(
            snapshot: snapshot,
            rule: rule,
            activeKeys: activeAlertKeys
        )
        activeAlertKeys = nextKeys
        alerts.insert(contentsOf: events, at: 0)
        for event in events {
            Task {
                await notifier.notify(title: event.title, body: event.detail)
            }
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let minutes = await MainActor.run { self.refreshMinutes }
                let seconds = UInt64(max(1, minutes) * 60)
                try? await Task.sleep(for: .seconds(seconds))
                if Task.isCancelled { return }
                await self.refreshNow()
            }
        }
    }

    private func tokenPreview(_ token: String) -> String {
        guard token.count > 10 else { return l10n.savedToken }
        return "\(token.prefix(6))...\(token.suffix(4))"
    }

    private func updateAppIcon() {
        NSApp.applicationIconImage = AppIconRenderer.image(tone: iconTone)
    }
}
