import SwiftUI

/// Browses categories -> items for Live TV and Movies (VOD), which share the same
/// two-level shape. Series has an extra level (episodes) and gets its own view.
///
/// Everything is fetched in one request per media kind (not one request per
/// category) — some Xtream providers reject many rapid concurrent connections,
/// and per-category loading made search painfully slow. Categories/search are
/// then grouped and filtered client-side from that single in-memory list.
struct StreamCategoryBrowser<Item: StreamItem>: View {
    let client: XtreamClient
    let kind: MediaKind
    let loadCategories: () async throws -> [XtreamCategory]
    let loadAllItems: () async throws -> [Item]
    let extensionForItem: (Item) -> String?
    let onPlay: (String, URL) -> Void

    @State private var categories: [XtreamCategory] = []
    @State private var allItems: [Item] = []
    @State private var expandedCategoryIds: Set<String> = []
    @State private var favoriteCategoryIds: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    /// Favoriting is only offered for Live TV: with hundreds of channels spread
    /// across many categories, pinning the ones you actually watch to the top
    /// saves real digging. Movies/Series are usually watched once, so it's not
    /// worth the extra UI there.
    private var supportsFavorites: Bool { kind == .live }

    private var favoritesKey: String { "favoriteCategories.\(client.profile.id.uuidString).\(kind.rawValue)" }

    private let columns = [GridItem(.adaptive(minimum: 210, maximum: 320), spacing: 8)]

    /// Live TV has relatively few, meaningful categories (news, sports, region…),
    /// so searching by category name is the more useful mode there. Movies/Series
    /// have dozens of thin genre categories but the user is almost always looking
    /// for a specific title, so those search by item name instead.
    private var searchesByCategory: Bool { kind == .live }

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView("Σφάλμα", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if searchText.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(orderedCategories) { category in
                            categorySection(category)
                        }
                    }
                    .padding(16)
                }
            } else if searchesByCategory {
                if matchingCategories.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(matchingCategories) { category in
                                categorySection(category)
                            }
                        }
                        .padding(16)
                    }
                }
            } else if matchingItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(matchingItems, id: \.id) { item in
                            itemRow(item)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea())
        .searchable(text: $searchText, prompt: searchesByCategory ? "Αναζήτηση κατηγορίας" : "Αναζήτηση")
        .task {
            loadFavorites()
            await loadAll()
        }
    }

    /// Favorited categories first (in their original relative order), then
    /// everything else — this is what actually pins them to the top of the list.
    private var orderedCategories: [XtreamCategory] {
        guard supportsFavorites, !favoriteCategoryIds.isEmpty else { return categories }
        let favorites = categories.filter { favoriteCategoryIds.contains($0.id) }
        let rest = categories.filter { !favoriteCategoryIds.contains($0.id) }
        return favorites + rest
    }

    private func loadFavorites() {
        guard supportsFavorites else { return }
        favoriteCategoryIds = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
    }

    private func toggleFavorite(_ category: XtreamCategory) {
        if favoriteCategoryIds.contains(category.id) {
            favoriteCategoryIds.remove(category.id)
        } else {
            favoriteCategoryIds.insert(category.id)
        }
        UserDefaults.standard.set(Array(favoriteCategoryIds), forKey: favoritesKey)
    }

    private var symbol: String { kind == .live ? "tv" : "film" }

    private var itemsByCategory: [String: [Item]] {
        Dictionary(grouping: allItems, by: { $0.categoryId })
    }

    /// While searching, categories matching the text are shown pre-expanded.
    private var matchingCategories: [XtreamCategory] {
        guard !searchText.isEmpty else { return orderedCategories }
        return orderedCategories.filter { $0.categoryName.localizedCaseInsensitiveContains(searchText) }
    }

    private var matchingItems: [Item] {
        allItems
            .filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.displayName < $1.displayName }
    }

    @ViewBuilder
    private func categorySection(_ category: XtreamCategory) -> some View {
        let isExpanded = !searchText.isEmpty || expandedCategoryIds.contains(category.id)
        let items = itemsByCategory[category.id] ?? []
        let isFavorite = favoriteCategoryIds.contains(category.id)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
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
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if supportsFavorites {
                    Button {
                        toggleFavorite(category)
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)

            if isExpanded {
                if items.isEmpty {
                    Text("Καμία διαθέσιμη εγγραφή.")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                        .padding(.bottom, 6)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(items, id: \.id) { item in
                            itemRow(item)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func itemRow(_ item: Item) -> some View {
        Button {
            play(item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(item.displayName)
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

    private func play(_ item: Item) {
        guard let url = client.streamURL(kind: kind, id: item.id, containerExtension: extensionForItem(item)) else { return }
        onPlay(item.displayName, url)
    }

    private func loadAll() async {
        guard categories.isEmpty && allItems.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let categoriesTask = loadCategories()
            async let itemsTask = loadAllItems()
            let (cats, items) = try await (categoriesTask, itemsTask)
            categories = cats
            allItems = items
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
