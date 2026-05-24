import Charts
import SwiftUI

struct TrendPanel: View {
    enum Mode {
        case money
        case tokens
        case requests
        case typed([UsageType])
    }

    fileprivate struct SeriesPoint: Identifiable {
        var date: Date
        var label: String
        var type: UsageType?
        var value: Decimal
        var color: Color

        var id: String {
            "\(date.timeIntervalSince1970)-\(label)"
        }
    }

    var title: String
    var data: [DailyMetric]
    var currency: String
    var mode: Mode
    var l10n: L10n

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let selected = selectedMetric {
                    Text(Formatters.shortDay.string(from: selected.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart(seriesPoints) { point in
                if usesStackedBars {
                    BarMark(
                        x: .value(l10n.selectedDate, point.date),
                        y: .value(point.label, point.doubleValue)
                    )
                    .foregroundStyle(point.color)
                    .position(by: .value(l10n.tokens, point.label))
                } else {
                    AreaMark(
                        x: .value(l10n.selectedDate, point.date),
                        y: .value(point.label, point.doubleValue)
                    )
                    .foregroundStyle(point.color.opacity(0.16))
                    LineMark(
                        x: .value(l10n.selectedDate, point.date),
                        y: .value(point.label, point.doubleValue)
                    )
                    .foregroundStyle(point.color)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value(l10n.selectedDate, point.date),
                        y: .value(point.label, point.doubleValue)
                    )
                    .foregroundStyle(point.color)
                    .opacity(point.date == selectedMetric?.date ? 1 : 0)
                }

                if let selectedMetric, point.date == selectedMetric.date {
                    RuleMark(x: .value(l10n.selectedDate, selectedMetric.date))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            TrendAnnotation(metric: selectedMetric, mode: mode, currency: currency, l10n: l10n)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5))
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let double = value.as(Double.self) {
                            Text(axisLabel(double))
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                updateSelection(location: location, proxy: proxy, geometry: geometry)
                            case .ended:
                                selectedDate = nil
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelection(location: value.location, proxy: proxy, geometry: geometry)
                                }
                                .onEnded { _ in selectedDate = nil }
                        )
                }
            }
            .frame(height: 240)

            if usesStackedBars {
                HStack(spacing: 14) {
                    ForEach(seriesLabels, id: \.self) { label in
                        Label(label, systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(color(for: label))
                    }
                }
            }
        }
        .padding(18)
        .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var usesStackedBars: Bool {
        if case .typed = mode { return true }
        return false
    }

    private var seriesLabels: [String] {
        switch mode {
        case .typed(let types):
            return types.map { $0.title(language: l10n.language) }
        default:
            return [title]
        }
    }

    private var seriesPoints: [SeriesPoint] {
        data.flatMap { item in
            switch mode {
            case .money:
                [SeriesPoint(date: item.date, label: title, value: item.total, color: .orange)]
            case .tokens:
                [SeriesPoint(date: item.date, label: title, value: item.tokenTotal, color: .blue)]
            case .requests:
                [SeriesPoint(date: item.date, label: title, value: Decimal(item.requests), color: .cyan)]
            case .typed(let types):
                types.map { type in
                    SeriesPoint(
                        date: item.date,
                        label: type.title(language: l10n.language),
                        type: type,
                        value: item.amount(for: type),
                        color: color(for: type)
                    )
                }
            }
        }
    }

    private var selectedMetric: DailyMetric? {
        guard let selectedDate else { return nil }
        return data.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedDate)) < abs(rhs.date.timeIntervalSince(selectedDate))
        }
    }

    private func updateSelection(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let frame = proxy.plotFrame else { return }
        let origin = geometry[frame].origin
        let x = location.x - origin.x
        if let date: Date = proxy.value(atX: x) {
            selectedDate = date
        }
    }

    private func axisLabel(_ value: Double) -> String {
        switch mode {
        case .money:
            return Formatters.money(Decimal(value), currency: currency)
        case .requests:
            return Formatters.decimal(Decimal(value), fractionDigits: 0)
        case .tokens, .typed:
            return Formatters.decimal(Decimal(value), fractionDigits: 0)
        }
    }

    private func color(for label: String) -> Color {
        if label == UsageType.promptCacheHitToken.title(language: l10n.language) {
            return .green
        }
        if label == UsageType.promptCacheMissToken.title(language: l10n.language) {
            return .orange
        }
        if label == UsageType.responseToken.title(language: l10n.language) {
            return .blue
        }
        return .cyan
    }

    private func color(for type: UsageType) -> Color {
        switch type {
        case .promptCacheHitToken: .green
        case .promptCacheMissToken: .orange
        case .responseToken: .blue
        case .request: .cyan
        case .promptToken: .purple
        case .unknown: .secondary
        }
    }
}

private extension TrendPanel.SeriesPoint {
    var doubleValue: Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private struct TrendAnnotation: View {
    var metric: DailyMetric
    var mode: TrendPanel.Mode
    var currency: String
    var l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Formatters.shortDay.string(from: metric.date))
                .font(.caption.bold())
                .foregroundStyle(.primary)

            switch mode {
            case .money:
                annotationRow(label: l10n.cost, value: Formatters.money(metric.total, currency: currency))
            case .tokens:
                annotationRow(label: l10n.totalTokens, value: Formatters.decimal(metric.tokenTotal, fractionDigits: 0))
            case .requests:
                annotationRow(label: l10n.apiRequests, value: Formatters.decimal(Decimal(metric.requests), fractionDigits: 0))
            case .typed(let types):
                ForEach(types, id: \.self) { type in
                    annotationRow(
                        label: type.title(language: l10n.language),
                        value: Formatters.decimal(metric.amount(for: type), fractionDigits: 0)
                    )
                }
            }
        }
        .fixedSize()
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.96), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    private func annotationRow(label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(.caption)
    }
}
