import SwiftUI

struct MetricTable: View {
    enum ValueStyle {
        case number
        case money(String)
    }

    enum Column: Hashable {
        case request
        case promptCacheHitToken
        case promptCacheMissToken
        case responseToken
        case tokenTotal
        case total

        func title(l10n: L10n) -> String {
            switch self {
            case .request: l10n.apiRequests
            case .promptCacheHitToken: l10n.cacheHit
            case .promptCacheMissToken: l10n.cacheMiss
            case .responseToken: l10n.responseTokens
            case .tokenTotal: l10n.totalTokens
            case .total: l10n.total
            }
        }

        func value(in model: ModelMetric) -> Decimal {
            switch self {
            case .request: model.amount(for: .request)
            case .promptCacheHitToken: model.cacheHitTokens
            case .promptCacheMissToken: model.cacheMissTokens
            case .responseToken: model.responseTokens
            case .tokenTotal: model.tokenTotal
            case .total: model.total
            }
        }
    }

    var title: String
    var models: [ModelMetric]
    var valueStyle: ValueStyle
    var columns: [Column]
    var l10n: L10n

    @State private var hoveredCell: CellID?

    private struct CellID: Hashable {
        var model: String
        var column: Column
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    Text(l10n.model).foregroundStyle(.secondary)
                    ForEach(columns, id: \.self) { column in
                        Text(column.title(l10n: l10n))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                    }
                }
                .font(.caption)

                Divider()
                    .gridCellColumns(columns.count + 1)

                ForEach(models) { model in
                    GridRow {
                        Text(model.model)
                            .fontWeight(.medium)
                            .padding(.vertical, 4)
                        ForEach(columns, id: \.self) { column in
                            let value = column.value(in: model)
                            Text(format(value))
                                .fontWeight(column == .total || column == .tokenTotal ? .semibold : .regular)
                                .monospacedDigit()
                                .gridColumnAlignment(.trailing)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .background(
                                    cellID(model: model, column: column) == hoveredCell
                                        ? Color.primary.opacity(0.06)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                                .help(helpText(model: model, column: column, value: value))
                                .onHover { isHovered in
                                    hoveredCell = isHovered ? cellID(model: model, column: column) : nil
                                }
                        }
                    }
                }
            }
        }
        .padding(18)
        .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func format(_ value: Decimal) -> String {
        switch valueStyle {
        case .number:
            return Formatters.compactDecimal(value)
        case .money(let currency):
            return Formatters.money(value, currency: currency)
        }
    }

    private func preciseFormat(_ value: Decimal) -> String {
        switch valueStyle {
        case .number:
            return Formatters.decimal(value, fractionDigits: 0)
        case .money(let currency):
            return Formatters.money(value, currency: currency)
        }
    }

    private func cellID(model: ModelMetric, column: Column) -> CellID {
        CellID(model: model.model, column: column)
    }

    private func helpText(model: ModelMetric, column: Column, value: Decimal) -> String {
        "\(l10n.model)：\(model.model)\n\(column.title(l10n: l10n))：\(preciseFormat(value))"
    }
}

struct EmptyMetricPlaceholder: View {
    var title: String = "暂无数据"
    var detail: String = "登录并刷新后会加载 DeepSeek 平台数据。"
    var systemImage: String = "chart.bar.xaxis"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
    }
}
