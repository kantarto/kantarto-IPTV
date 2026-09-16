import SwiftUI

enum BrowseSection: String, CaseIterable, Identifiable {
    case live = "Live TV"
    case movies = "Ταινίες"
    case series = "Σειρές"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .live: return "tv"
        case .movies: return "film"
        case .series: return "tv.badge.wifi"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var selectedSection: BrowseSection = .live
    @State private var playerTitle: String?
    @State private var playerURL: URL?
    @State private var playerIsLive = true
    @State private var showingAddProfile = false
    @State private var editingProfile: XtreamProfile?
    // Cached so the Keychain isn't re-read (and macOS doesn't re-prompt) on every
    // re-render — only when the selected playlist actually changes.
    @State private var activeClient: XtreamClient?

    var body: some View {
        if profileStore.selectedProfile == nil {
            emptyState
        } else {
            NavigationSplitView {
                sidebar
            } content: {
                content
            } detail: {
                PlayerView(title: playerTitle, url: playerURL, isLive: playerIsLive)
            }
            .sheet(isPresented: $showingAddProfile) {
                AddProfileView()
                    .environmentObject(profileStore)
            }
            .sheet(item: $editingProfile) { profile in
                AddProfileView(editingProfile: profile)
                    .environmentObject(profileStore)
            }
            .onAppear { refreshClient() }
            .onChange(of: profileStore.selectedProfileId) { _, _ in refreshClient() }
        }
    }

    private func refreshClient() {
        guard let profile = profileStore.selectedProfile else {
            activeClient = nil
            return
        }
        activeClient = XtreamClient(profile: profile, password: profileStore.password(for: profile))
    }

    private var emptyState: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.10, blue: 0.20),
                    Color(red: 0.03, green: 0.04, blue: 0.09),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                ProfileAvatarView(diameter: 132, ringWidth: 3)
                    .padding(.bottom, 4)

                VStack(spacing: 6) {
                    Text("kantarto IPTV")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Η προσωπική σου εφαρμογή IPTV")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text("Πρόσθεσε μια Xtream playlist για να ξεκινήσεις.")
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 8)

                Button {
                    showingAddProfile = true
                } label: {
                    Label("Προσθήκη Playlist", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color(red: 0.20, green: 0.48, blue: 0.98))
                .padding(.top, 6)
            }
            .padding(48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddProfile) {
            AddProfileView()
                .environmentObject(profileStore)
        }
    }

    private var sidebar: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    ProfileAvatarView(diameter: 60, ringWidth: 2.5)
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 4)
                    VStack(spacing: 2) {
                        Text("kantarto IPTV")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        if let profile = profileStore.selectedProfile {
                            Text(profile.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Playlist") {
                Picker("Playlist", selection: $profileStore.selectedProfileId) {
                    ForEach(profileStore.profiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .labelsHidden()

                if let profile = profileStore.selectedProfile {
                    Button {
                        editingProfile = profile
                    } label: {
                        Label("Επεξεργασία…", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        profileStore.removeProfile(profile)
                    } label: {
                        Label("Διαγραφή", systemImage: "trash")
                    }
                }
                Button {
                    showingAddProfile = true
                } label: {
                    Label("Νέα Playlist…", systemImage: "plus.circle")
                }
            }

            Section("Περιεχόμενο") {
                ForEach(BrowseSection.allCases) { section in
                    sectionRow(section)
                }
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.sidebar)
        .navigationTitle("kantarto IPTV")
    }

    private func sectionRow(_ section: BrowseSection) -> some View {
        let isSelected = selectedSection == section
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 26, height: 26)
                    Image(systemName: section.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.primary.opacity(0.7))
                }
                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                .padding(.vertical, 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        if let profile = profileStore.selectedProfile, let client = activeClient {
            switch selectedSection {
            case .live:
                StreamCategoryBrowser<LiveStream>(
                    client: client,
                    kind: .live,
                    loadCategories: { try await client.liveCategories() },
                    loadAllItems: { try await client.liveStreams() },
                    extensionForItem: { _ in nil },
                    onPlay: { title, url in
                        playerTitle = title
                        playerURL = url
                        playerIsLive = true
                    }
                )
                .id("\(profile.id)-live")
                .navigationTitle(BrowseSection.live.rawValue)
            case .movies:
                StreamCategoryBrowser<VODStream>(
                    client: client,
                    kind: .movie,
                    loadCategories: { try await client.vodCategories() },
                    loadAllItems: { try await client.vodStreams() },
                    extensionForItem: { $0.containerExtension },
                    onPlay: { title, url in
                        playerTitle = title
                        playerURL = url
                        playerIsLive = false
                    }
                )
                .id("\(profile.id)-movies")
                .navigationTitle(BrowseSection.movies.rawValue)
            case .series:
                SeriesBrowserView(client: client) { title, url in
                    playerTitle = title
                    playerURL = url
                    playerIsLive = false
                }
                .id("\(profile.id)-series")
                .navigationTitle(BrowseSection.series.rawValue)
            }
        }
    }
}
