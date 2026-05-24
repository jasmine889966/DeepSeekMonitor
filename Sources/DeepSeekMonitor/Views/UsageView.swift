import Charts
import SwiftUI

struct UsageView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let snapshot = store.snapshot {
                    TrendPanel(title: store.l10n.dailyRequests, data: snapshot.usage.dailyTotals, currency: snapshot.account.currency, mode: .requests, l10n: store.l10n)
                    MetricTable(title: store.l10n.requestsByModel, models: snapshot.usage.modelTotals, valueStyle: .number, columns: [.request], l10n: store.l10n)
                    TrendPanel(title: store.l10n.dailyTokens, data: snapshot.usage.dailyTotals, currency: snapshot.account.currency, mode: .typed([.promptCacheHitToken, .promptCacheMissToken, .responseToken]), l10n: store.l10n)
                    MetricTable(title: store.l10n.tokensByModel, models: snapshot.usage.modelTotals, valueStyle: .number, columns: [.promptCacheHitToken, .promptCacheMissToken, .responseToken, .tokenTotal], l10n: store.l10n)
                } else {
                    EmptyMetricPlaceholder(
                        title: store.authState == .expired ? store.l10n.loginExpired : store.l10n.noMetrics,
                        detail: store.authState == .expired ? store.l10n.loginExpiredDetail : store.l10n.noMetricsDetail,
                        systemImage: store.authState == .expired ? "exclamationmark.triangle" : "chart.bar.xaxis"
                    )
                }
            }
            .padding(24)
        }
    }
}
