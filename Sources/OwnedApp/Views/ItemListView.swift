import SwiftUI

private enum StatusFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case active
    case expiringSoon
    case expired

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .expiringSoon: return "Soon"
        case .expired: return "Expired"
        }
    }

    func matches(_ item: TrackedItem) -> Bool {
        switch self {
        case .all: return true
        case .active: return item.overallStatus == .active
        case .expiringSoon: return item.overallStatus == .expiringSoon
        case .expired: return item.overallStatus == .expired
        }
    }
}

private enum SortOption: String, CaseIterable, Identifiable, Hashable {
    case urgency
    case recentlyAdded
    case priceHighToLow
    case priceLowToHigh
    case nameAZ

    var id: String { rawValue }

    var label: String {
        switch self {
        case .urgency: return "Most urgent first"
        case .recentlyAdded: return "Recently added"
        case .priceHighToLow: return "Price: high to low"
        case .priceLowToHigh: return "Price: low to high"
        case .nameAZ: return "Name (A–Z)"
        }
    }

    var systemImage: String {
        switch self {
        case .urgency: return "flame"
        case .recentlyAdded: return "clock"
        case .priceHighToLow: return "arrow.down"
        case .priceLowToHigh: return "arrow.up"
        case .nameAZ: return "textformat"
        }
    }
}

struct ItemListView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @State private var isPresentingAddItem = false
    @State private var isPresentingGmailImport = false
    @State private var searchText = ""
    @State private var statusFilter: StatusFilter = .all
    @State private var categoryFilter: ItemCategory?
    @State private var sortOption: SortOption = .urgency

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !itemStore.items.isEmpty {
                    statusFilterRow
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    }

                Group {
                    if itemStore.items.isEmpty {
                        emptyState
                    } else if visibleItems.isEmpty {
                        noResultsState
                    } else {
                        List {
                            ForEach(visibleItems) { item in
                                NavigationLink(value: item.id) {
                                    row(for: item)
                                }
                                .listRowBackground(Theme.panel)
                            }
                            .onDelete { offsets in
                                let idsToDelete = offsets.map { visibleItems[$0].id }
                                for id in idsToDelete {
                                    if let item = itemStore.items.first(where: { $0.id == id }) {
                                        NotificationService.shared.cancelReminders(for: item)
                                        itemStore.delete(item)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .listRowSeparatorTint(Theme.border)
                        .themedScrollBackground()
                        .monospacedDigit()
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Owned")
            .searchable(text: $searchText, prompt: "Search your purchases")
            .navigationDestination(for: UUID.self) { itemID in
                if let item = itemStore.items.first(where: { $0.id == itemID }) {
                    ItemDetailView(item: item)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addMenu
                }
                ToolbarItem(placement: .secondaryAction) {
                    sortMenu
                }
                if usedCategories.count > 1 {
                    ToolbarItem(placement: .secondaryAction) {
                        filterMenu
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $isPresentingGmailImport) {
                GmailImportSheet()
            }
        }
    }

    /// The "+" button was a plain shortcut straight to the manual form,
    /// which buried "Add from Gmail" three taps deep in Settings even
    /// though it's the whole point of Owned's automatic-tracking pitch.
    /// A menu puts both entry points where a person actually looks for
    /// "add" to happen. Both this menu and the empty state below present
    /// the identical `GmailImportSheet`, so there's exactly one place the
    /// connect/scan/paywall logic lives, not a copy per entry point.
    private var addMenu: some View {
        Menu {
            Button {
                isPresentingAddItem = true
            } label: {
                Label("Add manually", systemImage: "square.and.pencil")
            }
            Button {
                isPresentingGmailImport = true
            } label: {
                Label("Add from Gmail", systemImage: "envelope")
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    // MARK: - Filtering & sorting

    /// Which categories actually appear among tracked items right now —
    /// used to decide whether the category filter row is worth showing at
    /// all (no point offering a filter with only one or zero options).
    private var usedCategories: [ItemCategory] {
        Array(Set(itemStore.items.compactMap(\.category))).sorted { $0.label < $1.label }
    }

    /// The items actually shown after applying the status filter, the
    /// category filter, the search text, and the chosen sort order.
    /// Recomputed on every view update rather than cached — the item
    /// count here is small (a few hundred at most, per ItemStore's own
    /// design assumption), so a plain filter+sort is more than fast
    /// enough and needs no caching.
    private var visibleItems: [TrackedItem] {
        var items = itemStore.items.filter { statusFilter.matches($0) }

        if let categoryFilter {
            items = items.filter { $0.category == categoryFilter }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedSearch)
                || $0.retailer.localizedCaseInsensitiveContains(trimmedSearch)
            }
        }

        switch sortOption {
        case .urgency:
            items.sort { lhs, rhs in
                let l = lhs.soonestDeadline?.date ?? .distantFuture
                let r = rhs.soonestDeadline?.date ?? .distantFuture
                return l < r
            }
        case .recentlyAdded:
            items.sort { $0.purchaseDate > $1.purchaseDate }
        case .priceHighToLow:
            items.sort { ($0.priceCents ?? -1) > ($1.priceCents ?? -1) }
        case .priceLowToHigh:
            items.sort { ($0.priceCents ?? Int.max) < ($1.priceCents ?? Int.max) }
        case .nameAZ:
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return items
    }

/// A custom capsule-chip row standing in for a default segmented
    /// `Picker`. This is the one filter kept permanently visible — an
    /// "always" action, in the Obvious/Easy/Possible sense — while
    /// category filtering (a "sometimes" action for most people's
    /// purchase counts) lives one tap away behind the toolbar's Filter
    /// menu instead of a second permanent row competing for space.
private var statusFilterRow: some View {
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatusFilter.allCases) { filter in
                    chip(label: filter.label, isSelected: statusFilter == filter) {
                        statusFilter = filter
                    }
                }
            }
            .padding(.horizontal)
        }
    }

private var filterMenu: some View {
    Menu {
        Picker("Category", selection: $categoryFilter) {
            Text("All categories").tag(ItemCategory?.none)
            ForEach(usedCategories) { category in
                                     Label(category.label, systemImage: category.systemImage).tag(ItemCategory?.some(category))
                                    }
        }
    } label: {
        Label("Filter", systemImage: categoryFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
    }
}
    
    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.accent : Theme.panel)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textDim)
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : Theme.border, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.label, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        EmptyStateView(
            icon: "shippingbox",
            title: "Nothing tracked yet",
            message: "Add a purchase to track its return window or warranty.",
            actionTitle: "Add a purchase",
            action: { isPresentingAddItem = true },
            secondaryActionTitle: "Add from Gmail",
            secondaryAction: { isPresentingGmailImport = true }
        )
    }

    private var noResultsState: some View {
        EmptyStateView(
            icon: "line.3.horizontal.decrease.circle",
            title: "No matches",
            message: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No purchases match the \u{201C}\(statusFilter.label)\u{201D} filter."
                : "No purchases match \u{201C}\(searchText)\u{201D}."
        )
    }

    private func row(for item: TrackedItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    if item.resolvedAt != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.success)
                    }
                }
                HStack(spacing: 6) {
                    Text(item.retailer)
                    if let price = item.priceDisplay {
                        Text("·")
                        Text(price)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textDim)
            }

            Spacer()

            StatusBadge(deadline: item.soonestDeadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let store = ItemStore()
    return ItemListView()
        .environmentObject(store)
}
