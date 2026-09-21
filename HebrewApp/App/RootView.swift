import SwiftUI

/// Documentation/PRODUCT.md navigation: iPhone gets four tabs (Heute, Lernen, Wörter,
/// Fortschritt) with Settings on the toolbar and Review/Grammar reachable from within Heute/
/// Lernen; iPad gets a sidebar with the same targets plus direct Review/Grammar entries.
enum AppSection: String, CaseIterable, Identifiable {
    case today, learn, review, words, grammar, progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Heute"
        case .learn: "Lernen"
        case .review: "Wiederholen"
        case .words: "Wörter"
        case .grammar: "Grammatik"
        case .progress: "Fortschritt"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .learn: "book"
        case .review: "arrow.clockwise"
        case .words: "character.book.closed"
        case .grammar: "text.book.closed"
        case .progress: "chart.bar"
        }
    }

    @ViewBuilder @MainActor
    var destination: some View {
        switch self {
        case .today: TodayView()
        case .learn: LearnListView()
        case .review: ReviewView()
        case .words: WordsView()
        case .grammar: GrammarView()
        case .progress: LearnerProgressView()
        }
    }
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsSettings = false
    @State private var selectedSection: AppSection? = .today

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .sheet(isPresented: $showsSettings) { SettingsView() }
    }

    private var iPhoneLayout: some View {
        TabView {
            ForEach([AppSection.today, .learn, .words, .progress]) { section in
                NavigationStack {
                    section.destination
                        .navigationTitle(section.title)
                        .toolbar { settingsToolbarItem }
                }
                .tabItem { Label(section.title, systemImage: section.systemImage) }
            }
        }
        .tint(ColorTokens.primary)
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
            .navigationTitle("HebrewApp")
            .toolbar { settingsToolbarItem }
        } detail: {
            NavigationStack {
                let section = selectedSection ?? .today
                section.destination
                    .navigationTitle(section.title)
            }
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showsSettings = true
            } label: {
                Label("Einstellungen", systemImage: "gearshape")
            }
        }
    }
}
