import SwiftUI

struct MenuBarLabel: View {
    let store: MonitorStore

    var body: some View {
        let icon = Image(nsImage: AppIconRenderer.image(tone: store.iconTone, size: 18))
        if let account = store.snapshot?.account {
            Label {
                Text(Formatters.money(account.balance, currency: account.currency))
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
}

struct MenuBarView: View {
    @Bindable var store: MonitorStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            if let account = store.snapshot?.account {
                MenuBarMetrics(snapshot: store.snapshot, account: account, l10n: store.l10n)
            } else {
                Text(store.errorMessage ?? store.l10n.loginHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

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
        }
        .padding(16)
        .frame(width: 360)
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

private struct MenuBarMetrics: View {
    var snapshot: MonitorSnapshot?
    var account: AccountSummary
    var l10n: L10n

    private var todayModels: [ModelMetric] {
        (snapshot?.usage.today?.models ?? [])
            .filter { $0.tokenTotal > 0 || $0.requestCount > 0 }
            .sorted { $0.tokenTotal > $1.tokenTotal }
    }

    private var todayTotal: Decimal {
        snapshot?.usage.today?.tokenTotal ?? 0
    }

    private var monthlyTotal: Decimal {
        snapshot?.usage.modelTotals.tokenTotal ?? Decimal(account.monthlyTokenUsage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                metricRow(title: l10n.balance, value: Formatters.money(account.balance, currency: account.currency), emphasized: true)
                metricRow(title: l10n.monthlyCost, value: Formatters.money(account.monthlyCost, currency: account.currency))
                metricRow(title: l10n.monthlyTotalTokens, value: Formatters.compactDecimal(monthlyTotal))
                metricRow(title: l10n.todayTokens, value: Formatters.compactDecimal(todayTotal), emphasized: true)
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(l10n.byModel)
                        .font(.caption)
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
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(Formatters.compactDecimal(model.tokenTotal))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }

                    if todayModels.count > 4 {
                        Text("+\(todayModels.count - 4)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(allModelsHelp)
                    }
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .help(allModelsHelp)
        }
    }

    private func metricRow(title: String, value: String, emphasized: Bool = false) -> some View {
        GridRow {
            Text(title)
            Text(value)
                .fontWeight(emphasized ? .semibold : .regular)
                .monospacedDigit()
        }
    }

    private var allModelsHelp: String {
        guard !todayModels.isEmpty else { return l10n.todayNoUsage }
        return todayModels
            .map { "\($0.model)：\(Formatters.decimal($0.tokenTotal, fractionDigits: 0))" }
            .joined(separator: "\n")
    }
}
