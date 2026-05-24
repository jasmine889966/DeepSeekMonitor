import SwiftUI

struct SettingsView: View {
    @Bindable var store: MonitorStore

    var body: some View {
        Form {
            Section(store.l10n.refreshSection) {
                SettingsStepperRow(
                    title: store.l10n.interval,
                    value: $store.refreshMinutes,
                    range: 1...120,
                    step: 1,
                    suffix: "min"
                )
            }

            Section(store.l10n.alertSection) {
                SettingsDecimalRow(
                    title: store.l10n.balanceThreshold,
                    value: $store.balanceThresholdValue,
                    range: 0...1_000_000,
                    step: 1
                )
                SettingsDecimalRow(
                    title: store.l10n.monthlyCostThreshold,
                    value: $store.monthlyCostThresholdValue,
                    range: 0...1_000_000,
                    step: 1
                )
                SettingsStepperRow(
                    title: store.l10n.monthlyTokenThreshold,
                    value: $store.monthlyTokenLimit,
                    range: 1_000...1_000_000_000,
                    step: 1_000_000,
                    formatter: { Formatters.compactNumber($0) }
                )
            }

            Section(store.l10n.account) {
                LabeledContent(store.l10n.token) {
                    Text(store.lastTokenPreview ?? store.l10n.notConnected)
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    store.logout()
                } label: {
                    Label(store.l10n.forgotLogin, systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section(store.l10n.languageSetting) {
                Picker(store.l10n.languageSetting, selection: store.languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
            }
        }
        .formStyle(.grouped)
    }
}

private struct SettingsStepperRow: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int
    var suffix: String?
    var formatter: (Int) -> String

    init(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        suffix: String? = nil,
        formatter: @escaping (Int) -> String = { Formatters.compactNumber($0) }
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.suffix = suffix
        self.formatter = formatter
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Text(displayValue)
                    .monospacedDigit()
                    .frame(minWidth: 96, alignment: .trailing)
                    .contentTransition(.numericText())
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 56)
            }
        }
    }

    private var displayValue: String {
        if let suffix {
            return "\(formatter(value)) \(suffix)"
        }
        return formatter(value)
    }
}

private struct SettingsDecimalRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 110)
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 56)
            }
        }
    }
}
