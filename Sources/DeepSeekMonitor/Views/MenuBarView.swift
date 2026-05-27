import SwiftUI

struct MenuBarLabel: View {
    let store: MonitorStore

    var body: some View {
        let icon = Image(nsImage: AppIconRenderer.image(tone: store.statusBarIconTone, size: 18))
        if let snapshot = store.snapshot {
            Label {
                Text(statusTitle(for: snapshot))
            } icon: {
                icon
            }
        } else {
            Label {
                Text(store.l10n.appName)
            } icon: {
                icon
            }
        }
    }

    private func statusTitle(for snapshot: MonitorSnapshot) -> String {
        let todayCost = snapshot.costs.today?.total ?? 0
        let todayTokens = snapshot.usage.today?.tokenTotal ?? 0
        return "\(store.l10n.todayCost) \(Formatters.money(todayCost, currency: snapshot.costs.currency)) · \(Formatters.abbreviatedDecimal(todayTokens)) Token"
    }
}

struct MenuBarView: View {
    @Bindable var store: MonitorStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.l10n.appName)
                        .font(.headline)
                    Text(menuSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await store.refreshNow() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(store.l10n.refresh)
            }

            if let snapshot = store.snapshot {
                MenuBarMetrics(snapshot: snapshot, l10n: store.l10n)
            } else {
                Text(store.errorMessage ?? store.l10n.loginHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            MenuBarOfficialStatus(store: store)

            Divider()

            HStack {
                Button(store.l10n.openDashboard) {
                    openWindow(id: "dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)

                Button(store.l10n.quit) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 372)
    }

    private var menuSubtitle: String {
        if store.isRefreshing {
            return store.l10n.refreshing
        }
        if let date = store.snapshot?.refreshedAt {
            return store.l10n.updatedAt(date.formatted(date: .omitted, time: .shortened))
        }
        return store.l10n.notConnected
    }
}

private struct MenuBarOfficialStatus: View {
    let store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(store.l10n.officialStatus)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(statusTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
            }

            if let status = store.officialStatus {
                ForEach(status.components) { component in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(component.currentHealth.menuBarColor)
                            .frame(width: 6, height: 6)
                        Text(component.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(component.uptime)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.medium))
                }
            } else {
                Text(store.officialStatusErrorMessage ?? store.l10n.officialStatusLoading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(11)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }

    private var statusTitle: String {
        store.officialStatus?.summary.title(language: store.language) ?? store.l10n.notConnected
    }

    private var statusColor: Color {
        guard let summary = store.officialStatus?.summary else { return .secondary }
        return summary.menuBarColor
    }
}

private extension ServiceHealth {
    var menuBarColor: Color {
        switch self {
        case .operational:
            .green
        case .degraded, .maintenance:
            .yellow
        case .outage:
            .red
        case .unknown:
            .secondary
        }
    }
}

private struct MenuBarMetrics: View {
    var snapshot: MonitorSnapshot
    var l10n: L10n

    private var todayModels: [ModelMetric] {
        (snapshot.usage.today?.models ?? [])
            .filter { $0.tokenTotal > 0 || $0.requestCount > 0 }
            .sorted { $0.tokenTotal > $1.tokenTotal }
    }

    private var todayTotal: Decimal {
        snapshot.usage.today?.tokenTotal ?? 0
    }

    private var todayCost: Decimal {
        snapshot.costs.today?.total ?? 0
    }

    private var monthlyTotal: Decimal {
        snapshot.usage.modelTotals.tokenTotal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                MenuBarHighlightMetric(
                    title: l10n.todayCost,
                    value: Formatters.money(todayCost, currency: snapshot.costs.currency),
                    systemImage: "yensign.circle"
                )
                MenuBarHighlightMetric(
                    title: l10n.todayTokens,
                    value: Formatters.compactDecimal(todayTotal),
                    systemImage: "number.circle"
                )
            }

            HStack(spacing: 10) {
                MenuBarHighlightMetric(
                    title: l10n.balance,
                    value: Formatters.money(snapshot.account.balance, currency: snapshot.account.currency),
                    systemImage: "creditcard"
                )
                MenuBarHighlightMetric(
                    title: l10n.monthlyCost,
                    value: Formatters.money(snapshot.account.monthlyCost, currency: snapshot.account.currency),
                    systemImage: "yensign.arrow.circlepath"
                )
            }

            MenuBarHighlightMetric(
                title: l10n.monthlyTotalTokens,
                value: Formatters.compactDecimal(monthlyTotal),
                systemImage: "sum",
                isWide: true
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l10n.byModel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if todayModels.isEmpty {
                    Text(l10n.todayNoUsage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todayModels.prefix(4)) { model in
                        HStack(spacing: 8) {
                            Text(model.model)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(Formatters.compactDecimal(model.tokenTotal))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.caption.weight(.medium))
                    }

                    if todayModels.count > 4 {
                        Text("+\(todayModels.count - 4)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(allModelsHelp)
                    }
                }
            }
            .padding(11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 1)
            }
            .help(allModelsHelp)
        }
    }

    private var allModelsHelp: String {
        guard !todayModels.isEmpty else { return l10n.todayNoUsage }
        let metrics = [
            "\(l10n.todayCost)：\(Formatters.money(todayCost, currency: snapshot.costs.currency))",
            "\(l10n.todayTokens)：\(Formatters.decimal(todayTotal, fractionDigits: 0))"
        ]
        let models = todayModels.map { "\($0.model)：\(Formatters.decimal($0.tokenTotal, fractionDigits: 0))" }
        return (metrics + models).joined(separator: "\n")
    }
}

private struct MenuBarHighlightMetric: View {
    var title: String
    var value: String
    var systemImage: String
    var isWide = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.callout)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: isWide ? 22 : 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }
}
