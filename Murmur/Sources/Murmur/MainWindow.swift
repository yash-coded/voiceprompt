import SwiftUI

/// The five sidebar destinations, all functional.
enum SidebarSection: String, CaseIterable, Identifiable {
    case history = "History"
    case dictionary = "Dictionary"
    case stats = "Stats"
    case cleanupModes = "Cleanup Modes"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .dictionary: "character.book.closed"
        case .stats: "chart.bar"
        case .cleanupModes: "wand.and.stars"
        case .settings: "gearshape"
        }
    }
}

/// Main window: a sidebar shell over the five sections.
struct MainWindow: View {
    let settings: Settings
    @State private var section: SidebarSection = .settings

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $section) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch section {
            case .history:
                HistoryView(store: .shared)
            case .dictionary:
                DictionaryView(store: .shared)
            case .cleanupModes:
                CleanupModesView(store: .shared)
            case .stats:
                StatsView(store: .shared, historyEnabled: settings.historyRetention != .off)
            case .settings:
                SettingsView(settings: settings)
            }
        }
        .frame(minWidth: 640, minHeight: 440)
    }
}
