import Charts
import SwiftUI

struct OverviewView: View {
    @Bindable var store: MonitorStore
    @Binding var showsLogin: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatusStrip(store: store, showsLogin: $showsLogin)

                if let snapshot = store.snapshot {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                        MetricTile(
                            title: store.l10n.balance,
                            value: Formatters.money(snapshot.account.balance, currency: snapshot.account.currency),
                            systemImage: "creditcard",
                            tint: .green
                        )
                        MetricTile(
                            title: store.l10n.monthlyCost,
                            value: Formatters.money(snapshot.account.monthlyCost, currency: snapshot.account.currency),
                            systemImage: "yensign.arrow.circlepath",
                            tint: .orange
                        )
                        MetricTile(
                            title: store.l10n.todayCost,
                            value: Formatters.money(snapshot.costs.today?.total ?? 0, currency: snapshot.costs.currency),
                            systemImage: "yensign.circle",
                            tint: .pink
                        )
                        MetricTile(
                            title: store.l10n.todayTokens,
                            value: Formatters.compactDecimal(snapshot.usage.today?.tokenTotal ?? 0),
                            systemImage: "number.circle",
                            tint: .blue
                        )
                        MetricTile(
                            title: store.l10n.monthlyApiRequests,
                            value: Formatters.compactNumber(snapshot.usage.modelTotals.requestCount),
                            systemImage: "arrow.up.arrow.down.circle",
                            tint: .cyan
                        )
                        MetricTile(
                            title: store.l10n.totalTokens,
                            value: Formatters.compactDecimal(snapshot.usage.modelTotals.tokenTotal),
                            systemImage: "sum",
                            tint: .indigo
                        )
                    }

                    TrendPanel(title: store.l10n.costThisMonth, data: snapshot.costs.dailyTotals, currency: snapshot.costs.currency, mode: .money, l10n: store.l10n)
                    TrendPanel(title: store.l10n.tokenUsageThisMonth, data: snapshot.usage.dailyTotals, currency: snapshot.account.currency, mode: .tokens, l10n: store.l10n)
                } else {
                    EmptyStateView(
                        title: store.authState == .expired ? store.l10n.loginExpired : store.l10n.loginPrompt,
                        detail: store.authState == .expired ? store.l10n.loginExpiredDetail : store.l10n.loginPromptDetail,
                        systemImage: store.authState == .expired ? "exclamationmark.triangle" : "lock.open"
                    ) {
                        showsLogin = true
                    }
                }
            }
            .padding(24)
        }
        .background(.background)
    }
}

struct StatusStrip: View {
    @Bindable var store: MonitorStore
    @Binding var showsLogin: Bool

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: statusImage)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 34, height: 34)
                    .monitorGlass(Circle(), interactive: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 260, alignment: .leading)

            if let snapshot = store.snapshot {
                Divider()
                    .frame(height: 44)
                TodayUsageSummary(snapshot: snapshot, l10n: store.l10n)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            HStack(spacing: 8) {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await store.refreshNow() }
                } label: {
                    Label(store.l10n.refresh, systemImage: "arrow.clockwise")
                }

                Button {
                    showsLogin = true
                } label: {
                    Label(store.l10n.login, systemImage: "person.crop.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
    }

    private var statusImage: String {
        switch store.authState {
        case .authenticated: "checkmark.seal.fill"
        case .expired: "exclamationmark.triangle.fill"
        case .unauthenticated: "person.crop.circle.badge.plus"
        case .unknown: "hourglass"
        }
    }

    private var statusColor: Color {
        switch store.authState {
        case .authenticated: .green
        case .expired: .orange
        case .unauthenticated: .secondary
        case .unknown: .blue
        }
    }

    private var statusTitle: String {
        switch store.authState {
        case .authenticated: store.l10n.connected
        case .expired: store.l10n.loginExpired
        case .unauthenticated: store.l10n.notLoggedIn
        case .unknown: store.l10n.checkingSession
        }
    }

    private var statusDetail: String {
        if let error = store.errorMessage {
            return error
        }
        if let refreshedAt = store.snapshot?.refreshedAt {
            return store.l10n.updatedAt(refreshedAt.formatted(date: .omitted, time: .shortened))
        }
        if let preview = store.lastTokenPreview {
            return "\(store.l10n.token) \(preview)"
        }
        return store.l10n.loginHint
    }
}

struct TodayUsageSummary: View {
    var snapshot: MonitorSnapshot
    var l10n: L10n

    private var todayUsage: DailyMetric? {
        snapshot.usage.today
    }

    private var todayCost: DailyMetric? {
        snapshot.costs.today
    }

    private var modelRows: [ModelMetric] {
        (todayUsage?.models ?? [])
            .filter { $0.tokenTotal > 0 || $0.requestCount > 0 }
            .sorted { $0.tokenTotal > $1.tokenTotal }
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 16) {
                TodayMetricValue(
                    title: l10n.todayCost,
                    value: Formatters.money(todayCost?.total ?? 0, currency: snapshot.costs.currency)
                )
                TodayMetricValue(
                    title: l10n.todayTokens,
                    value: todayUsage.map { Formatters.compactDecimal($0.tokenTotal) } ?? "0"
                )
            }
            .frame(width: 300, alignment: .leading)

            if modelRows.isEmpty {
                Text(l10n.todayNoUsage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(modelRows.prefix(3)) { model in
                        TodayModelTokenPill(model: model, l10n: l10n)
                    }

                    if modelRows.count > 3 {
                        Text("+\(modelRows.count - 3)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.045), in: Capsule())
                            .help(allModelsHelp)
                    }
                }
                .lineLimit(1)
            }
        }
        .help(allModelsHelp)
    }

    private var allModelsHelp: String {
        guard !modelRows.isEmpty else { return l10n.todayNoUsage }
        let metrics = [
            "\(l10n.todayCost)：\(Formatters.money(todayCost?.total ?? 0, currency: snapshot.costs.currency))",
            "\(l10n.todayTokens)：\(Formatters.decimal(todayUsage?.tokenTotal ?? 0, fractionDigits: 0))"
        ]
        let models = modelRows.map { "\($0.model)：\(Formatters.decimal($0.tokenTotal, fractionDigits: 0))" }
        return (metrics + models).joined(separator: "\n")
    }
}

private struct TodayMetricValue: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(width: 142, alignment: .leading)
    }
}

private struct TodayModelTokenPill: View {
    var model: ModelMetric
    var l10n: L10n

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text(model.model)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(Formatters.compactDecimal(model.tokenTotal))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: 230)
        .background(Color.primary.opacity(0.045), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .help("\(l10n.model)：\(model.model)\n\(l10n.todayTokens)：\(Formatters.decimal(model.tokenTotal, fractionDigits: 0))")
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
    }
}

struct EmptyStateView: View {
    var title: String
    var detail: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button(systemImage == "lock.open" ? "登录" : "重新登录") {
                action()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .padding()
    }
}
