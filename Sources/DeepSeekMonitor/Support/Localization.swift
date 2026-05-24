import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    var isChinese: Bool {
        self == .simplifiedChinese
    }
}

struct L10n {
    let language: AppLanguage

    var appName: String { language.isChinese ? "DeepSeek 监控" : "DeepSeek Monitor" }
    var dashboard: String { language.isChinese ? "仪表盘" : "Dashboard" }
    var refresh: String { language.isChinese ? "刷新" : "Refresh" }
    var login: String { language.isChinese ? "登录" : "Login" }
    var relogin: String { language.isChinese ? "重新登录" : "Re-login" }
    var loginExpired: String { language.isChinese ? "登录已过期" : "Login expired" }
    var loginExpiredDetail: String {
        language.isChinese ? "当前令牌已失效，请重新登录后再刷新。" : "The current token is invalid. Please log in again and refresh."
    }
    var notLoggedIn: String { language.isChinese ? "尚未登录" : "Not logged in" }
    var checkingSession: String { language.isChinese ? "正在检查会话" : "Checking session" }
    var connected: String { language.isChinese ? "已连接 DeepSeek" : "Connected to DeepSeek" }
    var loginPrompt: String { language.isChinese ? "登录后开始监控" : "Login to start monitoring" }
    var loginPromptDetail: String {
        language.isChinese ? "登录 DeepSeek 后，这里会显示余额、用量和成本。" : "DeepSeek usage, costs, and balance will appear here after login."
    }
    var loginHint: String { language.isChinese ? "使用内置登录保存到本地配置。" : "Use the built-in login to save to local config." }
    var openDashboard: String { language.isChinese ? "打开仪表盘" : "Open Dashboard" }
    var quit: String { language.isChinese ? "退出" : "Quit" }
    var notConnected: String { language.isChinese ? "未连接" : "Not connected" }
    var refreshing: String { language.isChinese ? "刷新中…" : "Refreshing..." }
    func updatedAt(_ time: String) -> String {
        language.isChinese ? "更新于 \(time)" : "Updated \(time)"
    }
    var balance: String { language.isChinese ? "余额" : "Balance" }
    var monthlyCost: String { language.isChinese ? "本月消费" : "Monthly cost" }
    var monthlyApiRequests: String { language.isChinese ? "本月 API 请求数" : "Monthly API requests" }
    var totalTokens: String { language.isChinese ? "总 Token" : "Total tokens" }
    var monthlyTotalTokens: String { language.isChinese ? "本月总 Token" : "Monthly total tokens" }
    var monthlyTokens: String { language.isChinese ? "本月 Token" : "Monthly tokens" }
    var costThisMonth: String { language.isChinese ? "本月费用趋势" : "Cost this month" }
    var tokenUsageThisMonth: String { language.isChinese ? "本月 Token 趋势" : "Token usage this month" }
    var todayTokens: String { language.isChinese ? "今日 Token" : "Today's tokens" }
    var todayNoUsage: String { language.isChinese ? "今日暂无用量" : "No usage today" }
    var byModel: String { language.isChinese ? "按模型" : "By model" }
    var dailyTokens: String { language.isChinese ? "每日 Token" : "Daily tokens" }
    var dailyRequests: String { language.isChinese ? "每日 API 请求数" : "Daily requests" }
    var usageByModel: String { language.isChinese ? "按模型统计用量" : "Usage by model" }
    var requestsByModel: String { language.isChinese ? "按模型统计 API 请求数" : "Requests by model" }
    var tokensByModel: String { language.isChinese ? "按模型统计 Token" : "Tokens by model" }
    var dailyCost: String { language.isChinese ? "每日消费" : "Daily cost" }
    var costByModel: String { language.isChinese ? "按模型统计成本" : "Cost by model" }
    var model: String { language.isChinese ? "模型" : "Model" }
    var total: String { language.isChinese ? "总计" : "Total" }
    var exactValue: String { language.isChinese ? "精确值" : "Exact value" }
    var cost: String { language.isChinese ? "成本" : "Cost" }
    var cacheHit: String { language.isChinese ? "缓存命中" : "Cache hit" }
    var cacheMiss: String { language.isChinese ? "缓存未命中" : "Cache miss" }
    var responseTokens: String { language.isChinese ? "响应 Token" : "Response tokens" }
    var apiRequests: String { language.isChinese ? "API 请求数" : "API requests" }
    var tokens: String { language.isChinese ? "Token" : "Tokens" }
    var selectedDate: String { language.isChinese ? "日期" : "Date" }
    var searchMetrics: String { language.isChinese ? "搜索指标" : "Search metrics" }
    var noMetrics: String { language.isChinese ? "暂无数据" : "No metrics yet" }
    var noMetricsDetail: String { language.isChinese ? "登录并刷新后会加载 DeepSeek 平台数据。" : "Log in and refresh to load DeepSeek platform usage." }
    var alertHistory: String { language.isChinese ? "告警历史" : "Alert history" }
    var clear: String { language.isChinese ? "清空" : "Clear" }
    var refreshSection: String { language.isChinese ? "刷新" : "Refresh" }
    var alertSection: String { language.isChinese ? "告警" : "Alerts" }
    var settings: String { language.isChinese ? "设置" : "Settings" }
    var account: String { language.isChinese ? "账户" : "Account" }
    var token: String { language.isChinese ? "令牌" : "Token" }
    var forgotLogin: String { language.isChinese ? "忘记登录" : "Forget login" }
    var interval: String { language.isChinese ? "间隔" : "Interval" }
    var balanceThreshold: String { language.isChinese ? "余额阈值" : "Balance threshold" }
    var monthlyCostThreshold: String { language.isChinese ? "本月费用阈值" : "Monthly cost threshold" }
    var monthlyTokenThreshold: String { language.isChinese ? "本月 Token 阈值" : "Monthly token threshold" }
    var languageSetting: String { language.isChinese ? "语言" : "Language" }
    var tokenCaptureTitle: String { language.isChinese ? "DeepSeek 登录" : "DeepSeek Login" }
    var captureToken: String { language.isChinese ? "捕获令牌" : "Capture Token" }
    var cancel: String { language.isChinese ? "取消" : "Cancel" }
    var saveLoginSuccess: String { language.isChinese ? "令牌已保存。" : "Token captured and saved." }
    var captureTokenHint: String {
        language.isChinese ? "登录 DeepSeek 后，点击“捕获令牌”。" : "Sign in to DeepSeek, then press Capture Token."
    }
    var captureReady: String {
        language.isChinese ? "看到 usage 页面后即可捕获令牌。" : "When the usage page is visible, capture the token."
    }
    var captureWaiting: String {
        language.isChinese ? "请在浏览器中完成 DeepSeek 登录。" : "Complete DeepSeek login in the browser view."
    }
    var savedToken: String { language.isChinese ? "已保存" : "Saved" }
    var requestCurrentUser: String {
        language.isChinese ? "正在请求当前用户信息…" : "Requesting current DeepSeek user..."
    }
    func captureFailed(_ detail: String) -> String {
        language.isChinese ? "捕获失败：\(detail)" : "Capture failed: \(detail)"
    }
}
