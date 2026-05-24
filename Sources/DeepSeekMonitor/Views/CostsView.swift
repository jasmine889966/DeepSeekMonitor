import SwiftUI

struct CostsView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let snapshot = store.snapshot {
                    TrendPanel(title: store.l10n.dailyCost, data: snapshot.costs.dailyTotals, currency: snapshot.costs.currency, mode: .typed([.promptCacheHitToken, .promptCacheMissToken, .responseToken]), l10n: store.l10n)
                    MetricTable(title: store.l10n.costByModel, models: snapshot.costs.modelTotals, valueStyle: .money(snapshot.costs.currency), columns: [.promptCacheHitToken, .promptCacheMissToken, .responseToken, .total], l10n: store.l10n)
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
