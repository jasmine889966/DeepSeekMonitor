import SwiftUI

struct ServiceStatusView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ServiceStatusHeader(store: store)

                if let status = store.officialStatus {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(status.components) { component in
                            ServiceComponentStatusRow(component: component, l10n: store.l10n)
                        }
                    }
                    .padding(18)
                    .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    ServiceIncidentList(incidents: status.incidents, l10n: store.l10n)
                } else {
                    EmptyMetricPlaceholder(
                        title: store.l10n.officialStatusUnavailable,
                        detail: store.officialStatusErrorMessage ?? store.l10n.officialStatusLoading,
                        systemImage: "network.slash"
                    )
                }
            }
            .padding(24)
        }
    }
}

private struct ServiceStatusHeader: View {
    let store: MonitorStore

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: statusImage)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 34, height: 34)
                .monitorGlass(Circle(), interactive: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let url = store.officialStatus?.sourceURL ?? URL(string: "https://status.deepseek.com/") {
                Link(destination: url) {
                    Label(store.l10n.openOfficialStatus, systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
    }

    private var title: String {
        if let status = store.officialStatus {
            return status.summary.title(language: store.language)
        }
        return store.l10n.officialStatus
    }

    private var detail: String {
        if let error = store.officialStatusErrorMessage {
            return "\(store.l10n.officialStatusRefreshFailed)：\(error)"
        }
        if let status = store.officialStatus {
            return "\(status.summaryDetail.isEmpty ? store.l10n.allServicesOperating : status.summaryDetail) · \(store.l10n.updatedAt(status.refreshedAt.formatted(date: .omitted, time: .shortened)))"
        }
        return store.l10n.officialStatusLoading
    }

    private var statusImage: String {
        switch store.officialStatus?.summary {
        case .operational: "checkmark.seal.fill"
        case .degraded, .maintenance: "exclamationmark.triangle.fill"
        case .outage: "xmark.octagon.fill"
        case .unknown, nil: "hourglass"
        }
    }

    private var statusColor: Color {
        switch store.officialStatus?.summary {
        case .operational: .green
        case .degraded, .maintenance: .yellow
        case .outage: .red
        case .unknown, nil: .secondary
        }
    }
}

private struct ServiceComponentStatusRow: View {
    let component: ServiceComponentStatus
    let l10n: L10n

    private let columns = Array(repeating: GridItem(.fixed(7), spacing: 3), count: 30)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(component.currentHealth.statusColor)
                    .frame(width: 10, height: 10)
                Text(component.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(component.uptime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(component.days) { day in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(day.health.statusColor)
                        .frame(width: 7, height: 20)
                        .help("\(Formatters.day.string(from: day.date)) · \(day.health.title(language: l10n.language))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                ServiceLegendItem(color: .green, title: l10n.serviceOperational)
                ServiceLegendItem(color: .yellow, title: l10n.serviceDegraded)
                ServiceLegendItem(color: .red, title: l10n.serviceOutage)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ServiceLegendItem: View {
    let color: Color
    let title: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
    }
}

private struct ServiceIncidentList: View {
    let incidents: [ServiceIncident]
    let l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(l10n.recentIncidents)
                    .font(.headline)
                Spacer()
            }

            if incidents.isEmpty {
                Text(l10n.noRecentIncidents)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(incidents.prefix(10)) { incident in
                        ServiceIncidentRow(incident: incident, l10n: l10n)
                        if incident.id != incidents.prefix(10).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(18)
        .monitorGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ServiceIncidentRow: View {
    let incident: ServiceIncident
    let l10n: L10n

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: incident.status.lowercased() == "resolved" ? "checkmark.circle" : "exclamationmark.circle")
                .foregroundStyle(incident.status.lowercased() == "resolved" ? .green : .orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                if let link = incident.link {
                    Link(incident.title, destination: link)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                } else {
                    Text(incident.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Text(incident.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    if !incident.status.isEmpty {
                        Text(incident.status)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !incident.affectedComponents.isEmpty {
                    Text(incident.affectedComponents.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 11)
    }
}

private extension ServiceHealth {
    var statusColor: Color {
        switch self {
        case .operational: .green
        case .degraded, .maintenance: .yellow
        case .outage: .red
        case .unknown: .secondary
        }
    }
}
