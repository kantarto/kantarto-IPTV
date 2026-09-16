import SwiftUI

struct SeriesBrowserView: View {
    let client: XtreamClient
    let onPlay: (String, URL) -> Void

    @State private var categories: [XtreamCategory] = []
    @State private var allSeries: [SeriesItem] = []
    @State private var expandedCategoryIds: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedSeries: SeriesItem?

    private let columns = [GridItem(.adaptive(minimum: 210, maximum: 320), spacing: 8)]

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView("Σφάλμα", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if searchText.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(categories) { category in
                            categorySection(category)
                        }
                    }
                    .padding(16)
                }
            } else if matchingSeries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(matchingSeries) { series in
                            seriesRow(series)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Αναζήτηση")
        .task { await loadAll() }
        .sheet(item: $selectedSeries) { series in
            EpisodePickerView(client: client, series: series, onPlay: { name, url in
                selectedSeries = nil
                onPlay(name, url)
            })
        }
    }

    private var seriesByCategory: [String: [SeriesItem]] {
        Dictionary(grouping: allSeries, by: { $0.categoryId })
    }

    private var matchingSeries: [SeriesItem] {
        allSeries
            .filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.displayName < $1.displayName }
    }

    @ViewBuilder
    private func categorySection(_ category: XtreamCategory) -> some View {
        let isExpanded = expandedCategoryIds.contains(category.id)
        let items = seriesByCategory[category.id] ?? []
        VStack(alignment: .leading, spacing: 2) {
            Button {
                if isExpanded {
                    expandedCategoryIds.remove(category.id)
                } else {
                    expandedCategoryIds.insert(category.id)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                    Text(category.categoryName)
                        .font(.system(.headline, design: .rounded))
                    Text("\(items.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if items.isEmpty {
                    Text("Καμία διαθέσιμη εγγραφή.")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                        .padding(.bottom, 6)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(items) { series in
                            seriesRow(series)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func seriesRow(_ series: SeriesItem) -> some View {
        Button {
            selectedSeries = series
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tv.badge.wifi")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(series.displayName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.035)))
    }

    private func loadAll() async {
        guard categories.isEmpty && allSeries.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let categoriesTask = client.seriesCategories()
            async let seriesTask = client.series()
            let (cats, items) = try await (categoriesTask, seriesTask)
            categories = cats
            allSeries = items
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct EpisodePickerView: View {
    let client: XtreamClient
    let series: SeriesItem
    let onPlay: (String, URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var episodesBySeason: [String: [SeriesEpisode]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    ContentUnavailableView("Σφάλμα", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    List {
                        ForEach(sortedSeasons, id: \.self) { season in
                            Section("Season \(season)") {
                                ForEach(episodesBySeason[season] ?? []) { episode in
                                    Button {
                                        play(episode)
                                    } label: {
                                        Label(episode.displayName, systemImage: "play.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(series.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Κλείσιμο") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 520)
        .task { await loadEpisodes() }
    }

    private var sortedSeasons: [String] {
        episodesBySeason.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    private func loadEpisodes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            episodesBySeason = try await client.seriesEpisodes(seriesId: series.id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func play(_ episode: SeriesEpisode) {
        guard let url = client.streamURL(kind: .series, id: episode.id, containerExtension: episode.containerExtension) else { return }
        onPlay("\(series.displayName) — \(episode.displayName)", url)
    }
}
