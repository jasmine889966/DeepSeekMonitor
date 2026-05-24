import SwiftUI

struct SidebarView: View {
    @Binding var selection: MonitorSection
    var language: AppLanguage

    var body: some View {
        List(selection: $selection) {
            Section(language.isChinese ? "DeepSeek" : "DeepSeek") {
                ForEach(MonitorSection.allCases) { section in
                    Label(section.title(language: language), systemImage: section.systemImage)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(language.isChinese ? "监控" : "Monitor")
    }
}
