import SwiftUI

struct AlertsView: View {
    @Bindable var store: MonitorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(store.l10n.alertHistory)
                    .font(.title2.bold())
                Spacer()
                Button {
                    store.clearAlerts()
                } label: {
                    Label(store.l10n.clear, systemImage: "trash")
                }
                .disabled(store.alerts.isEmpty)
            }

            if store.alerts.isEmpty {
                EmptyMetricPlaceholder(
                    title: store.authState == .expired ? store.l10n.loginExpired : store.l10n.alertHistory,
                    detail: store.authState == .expired ? store.l10n.loginExpiredDetail : store.l10n.noMetricsDetail,
                    systemImage: store.authState == .expired ? "exclamationmark.triangle" : "bell"
                )
            } else {
                List(store.alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.title)
                            .font(.headline)
                        Text(alert.detail)
                            .foregroundStyle(.secondary)
                        Text(alert.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
    }
}
