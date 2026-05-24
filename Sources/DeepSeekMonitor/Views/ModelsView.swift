import SwiftUI

struct ModelsView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let snapshot = store.snapshot {
                    ForEach(snapshot.usage.modelTotals) { usageModel in
                        let costModel = snapshot.costs.modelTotals.first(where: { $0.model == usageModel.model })
                        ModelDetailCard(
                            usage: usageModel,
                            cost: costModel,
                            currency: snapshot.costs.currency,
                            l10n: store.l10n
                        )
                    }
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

struct ModelDetailCard: View {
    var usage: ModelMetric
    var cost: ModelMetric?
    var currency: String
    var l10n: L10n

    fileprivate struct MetricItem: Identifiable {
        var id: String { title }
        var title: String
        var value: String
        var help: String
        var systemImage: String
        var tint: Color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(usage.model, systemImage: "cpu")
                    .font(.headline)
                Spacer()
                Text(Formatters.money(cost?.total ?? 0, currency: currency))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(metricItems) { item in
                    ModelMetricChip(item: item)
                }
            }
        }
        .padding(18)
        .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var metricItems: [MetricItem] {
        [
            MetricItem(
                title: l10n.apiRequests,
                value: Formatters.compactNumber(usage.requestCount),
                help: "\(l10n.model)：\(usage.model)\n\(l10n.apiRequests)：\(Formatters.decimal(usage.amount(for: .request), fractionDigits: 0))",
                systemImage: "arrow.up.arrow.down.circle",
                tint: .cyan
            ),
            MetricItem(
                title: l10n.cacheHit,
                value: Formatters.compactDecimal(usage.cacheHitTokens),
                help: "\(l10n.model)：\(usage.model)\n\(l10n.cacheHit)：\(Formatters.decimal(usage.cacheHitTokens, fractionDigits: 0))",
                systemImage: "checkmark.circle",
                tint: .green
            ),
            MetricItem(
                title: l10n.cacheMiss,
                value: Formatters.compactDecimal(usage.cacheMissTokens),
                help: "\(l10n.model)：\(usage.model)\n\(l10n.cacheMiss)：\(Formatters.decimal(usage.cacheMissTokens, fractionDigits: 0))",
                systemImage: "xmark.circle",
                tint: .orange
            ),
            MetricItem(
                title: l10n.responseTokens,
                value: Formatters.compactDecimal(usage.responseTokens),
                help: "\(l10n.model)：\(usage.model)\n\(l10n.responseTokens)：\(Formatters.decimal(usage.responseTokens, fractionDigits: 0))",
                systemImage: "text.bubble",
                tint: .blue
            ),
            MetricItem(
                title: l10n.totalTokens,
                value: Formatters.compactDecimal(usage.tokenTotal),
                help: "\(l10n.model)：\(usage.model)\n\(l10n.totalTokens)：\(Formatters.decimal(usage.tokenTotal, fractionDigits: 0))",
                systemImage: "number.circle",
                tint: .purple
            ),
            MetricItem(
                title: l10n.cost,
                value: Formatters.money(cost?.total ?? 0, currency: currency),
                help: "\(l10n.model)：\(usage.model)\n\(l10n.cost)：\(Formatters.money(cost?.total ?? 0, currency: currency))",
                systemImage: "yensign.circle",
                tint: .orange
            )
        ]
    }
}

private struct ModelMetricChip: View {
    var item: ModelDetailCard.MetricItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(item.value)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            isHovered ? Color.primary.opacity(0.055) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHovered ? Color.primary.opacity(0.10) : Color.primary.opacity(0.04), lineWidth: 1)
        }
        .help(item.help)
        .onHover { isHovered = $0 }
    }
}
