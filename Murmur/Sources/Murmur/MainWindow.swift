import SwiftUI

/// The five sidebar destinations. Only Settings is functional in this slice;
/// the rest are placeholders that later slices (05–08) fill in.
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
            case .settings:
                SettingsView(settings: settings)
            default:
                ComingSoonView(section: section)
            }
        }
        .frame(minWidth: 640, minHeight: 440)
    }
}

/// Placeholder shown for sections that later slices implement.
private struct ComingSoonView: View {
    let section: SidebarSection

    var body: some View {
        ContentUnavailableView(
            section.rawValue,
            systemImage: section.systemImage,
            description: Text("Coming soon."))
    }
}
