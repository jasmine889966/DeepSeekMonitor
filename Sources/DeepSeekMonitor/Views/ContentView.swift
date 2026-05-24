import SwiftUI

struct ContentView: View {
    @Bindable var store: MonitorStore
    @State private var showsLogin = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $store.selectedSection, language: store.language)
        } detail: {
            Group {
                switch store.selectedSection {
                case .overview:
                    OverviewView(store: store, showsLogin: $showsLogin)
                case .usage:
                    UsageView(store: store)
                case .costs:
                    CostsView(store: store)
                case .models:
                    ModelsView(store: store)
                case .alerts:
                    AlertsView(store: store)
                case .settings:
                    SettingsView(store: store)
                        .padding(24)
                }
            }
            .navigationTitle(store.selectedSection.title(language: store.language))
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        Task { await store.refreshNow() }
                    } label: {
                        Label(store.l10n.refresh, systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)

                    Button {
                        showsLogin = true
                    } label: {
                        Label(loginTitle, systemImage: "person.crop.circle.badge.checkmark")
                    }
                }
            }
        }
        .searchable(text: .constant(""), placement: .toolbar, prompt: store.l10n.searchMetrics)
        .sheet(isPresented: $showsLogin) {
            let currentStore = store
            LoginSheet(l10n: store.l10n) { session in
                showsLogin = false
                await currentStore.saveSessionFromLogin(session)
            }
            .frame(width: 900, height: 700)
        }
    }

    private var loginTitle: String {
        switch store.authState {
        case .authenticated: store.l10n.relogin
        case .expired: store.l10n.loginExpired
        case .unauthenticated, .unknown: store.l10n.login
        }
    }
}
