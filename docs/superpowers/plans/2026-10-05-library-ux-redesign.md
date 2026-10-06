# Library UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Histórico and Perfil tabs with one Biblioteca tab (Favoritos / Assistidos / Histórico) with search, type filter, list/grid layout, swipe actions with undo and empty states, and give Ajustes a quota/account header card.

**Architecture:** A pure `LibraryFilter` turns `LibraryItem`s (title lives in the JSON `snapshotData`, so it cannot be queried with `#Predicate`) into decoded `LibraryEntry` values and filters them in memory by segment, text and media type. `LibraryStore` gains remove-per-segment and flag snapshot/restore (the undo). `LibraryView` is one `@Query` of every item with a flag plus the UI around it.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, XcodeGen (`project.yml`, sources are folder-based), iOS 18.

**Spec:** `docs/superpowers/specs/2026-10-05-library-ux-redesign-design.md`

## Global Constraints

- iOS deployment target 18.0, `SWIFT_VERSION: '6.0'` (strict concurrency).
- No schema change to `LibraryItem` / SwiftData.
- Source language is `pt-BR`; every new user-facing string also needs an `en` entry in `FilmFinder/Localizable.xcstrings` (Task 5).
- Colors via `Color.laranja`, `.cinza1`, `.cinza2`, `.branco`, `.rosa`, `.roxo`; app is forced dark mode.
- Out of scope: Recomendações/Resultados, onboarding, `TitleDetail`, backend.
- New files under `FilmFinder/` or `FilmFinderTests/` need `xcodegen generate` before building (the `.xcodeproj` is generated). If the build complains about `Local.xcconfig`, ignore: it is included with `#include?`.
- Test command (used throughout):
  `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FilmFinderTests/<SuiteName> 2>&1 | tail -30`
- Commit trailer on every commit: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`

---

### Task 1: LibraryFilter (segments, search, type filter)

**Files:**
- Create: `FilmFinder/Features/Library/LibraryFilter.swift`
- Test: `FilmFinderTests/LibraryFilterTests.swift`

**Interfaces:**
- Produces:
  - `enum LibrarySegment: String, CaseIterable, Identifiable, Sendable { case favorites, watched, history }`
  - `struct LibraryEntry: Identifiable { let id: String; let title: Title; let date: Date; let isFavorite: Bool; let isWatched: Bool; let inHistory: Bool; init?(_ item: LibraryItem); func isIn(_ segment: LibrarySegment) -> Bool }`
  - `struct LibraryFilter { var segment: LibrarySegment; var query: String = ""; var mediaType: MediaType? = nil; func apply(to entries: [LibraryEntry]) -> [LibraryEntry]; static func entries(from items: [LibraryItem]) -> [LibraryEntry]; static func count(_ segment: LibrarySegment, in entries: [LibraryEntry]) -> Int }`

- [ ] **Step 1: Write the failing tests**

Create `FilmFinderTests/LibraryFilterTests.swift`:

```swift
import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LibraryFilterTests {
    private func entries(_ h: LibraryHarness) -> [LibraryEntry] {
        LibraryFilter.entries(from: h.items.sorted { $0.libraryKey < $1.libraryKey })
    }

    private func pianist() -> Title {
        Title(
            tmdbId: 9, mediaType: .movie, title: "O Pianista", originalTitle: "The Pianist", year: 2002,
            overview: "", posterPath: nil, backdropPath: nil, rating: 8, runtimeMinutes: 150, seasons: nil,
            genres: [], reason: "", providers: .empty(region: "BR")
        )
    }

    @Test func segmentsSelectByFlag() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1), true)
        h.store.setWatched(.sample(id: 2), true)
        h.store.markShown(.sample(id: 3))
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites).apply(to: all).map(\.title.tmdbId) == [1])
        #expect(LibraryFilter(segment: .watched).apply(to: all).map(\.title.tmdbId) == [2])
        #expect(LibraryFilter(segment: .history).apply(to: all).map(\.title.tmdbId) == [3])
    }

    @Test func itemWithSeveralFlagsAppearsInEachSegment() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        h.store.setWatched(title, true)
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites).apply(to: all).count == 1)
        #expect(LibraryFilter(segment: .watched).apply(to: all).count == 1)
        #expect(LibraryFilter(segment: .history).apply(to: all).isEmpty)
    }

    @Test func searchIgnoresCaseAndAccentsAndMatchesOriginalTitle() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1, title: "Amélie"), true)
        h.store.setFavorite(pianist(), true)
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites, query: "amelie").apply(to: all).map(\.title.tmdbId) == [1])
        #expect(LibraryFilter(segment: .favorites, query: "PIANISTA").apply(to: all).map(\.title.tmdbId) == [9])
        #expect(LibraryFilter(segment: .favorites, query: "the pian").apply(to: all).map(\.title.tmdbId) == [9])
        #expect(LibraryFilter(segment: .favorites, query: "   ").apply(to: all).count == 2)
        #expect(LibraryFilter(segment: .favorites, query: "zzz").apply(to: all).isEmpty)
    }

    @Test func mediaTypeFilterKeepsOnlyThatType() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1, type: .movie), true)
        h.store.setFavorite(.sample(id: 2, type: .tv), true)
        let all = entries(h)

        #expect(LibraryFilter(segment: .favorites, mediaType: .tv).apply(to: all).map(\.title.tmdbId) == [2])
        #expect(LibraryFilter(segment: .favorites, mediaType: nil).apply(to: all).count == 2)
    }

    @Test func applyPreservesInputOrder() throws {
        let h = try LibraryHarness()
        for id in 1...3 { h.store.setFavorite(.sample(id: id), true) }
        let reversed = Array(entries(h).reversed())

        #expect(LibraryFilter(segment: .favorites).apply(to: reversed).map(\.title.tmdbId) == [3, 2, 1])
    }

    @Test func itemsWithUndecodableSnapshotAreSkipped() throws {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        try #require(h.item(title.id)).snapshotData = Data()

        #expect(entries(h).isEmpty)
    }

    @Test func countsPerSegment() throws {
        let h = try LibraryHarness()
        h.store.setFavorite(.sample(id: 1), true)
        h.store.setFavorite(.sample(id: 2), true)
        h.store.setWatched(.sample(id: 2), true)
        let all = entries(h)

        #expect(LibraryFilter.count(.favorites, in: all) == 2)
        #expect(LibraryFilter.count(.watched, in: all) == 1)
        #expect(LibraryFilter.count(.history, in: all) == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FilmFinderTests/LibraryFilterTests 2>&1 | tail -30`
Expected: build FAIL, `cannot find 'LibraryFilter' in scope`.

- [ ] **Step 3: Write the implementation**

Create `FilmFinder/Features/Library/LibraryFilter.swift`:

```swift
import Foundation

enum LibrarySegment: String, CaseIterable, Identifiable, Sendable {
    case favorites
    case watched
    case history

    var id: String { rawValue }
}

/// `LibraryItem` com o snapshot já decodificado: a decodificação acontece uma vez por render, não por consulta.
struct LibraryEntry: Identifiable {
    let id: String
    let title: Title
    let date: Date
    let isFavorite: Bool
    let isWatched: Bool
    let inHistory: Bool

    init?(_ item: LibraryItem) {
        guard let title = item.snapshot else { return nil }
        id = item.libraryKey
        self.title = title
        date = item.recommendedAt
        isFavorite = item.isFavorite
        isWatched = item.isWatched
        inHistory = item.inHistory
    }

    func isIn(_ segment: LibrarySegment) -> Bool {
        switch segment {
        case .favorites: isFavorite
        case .watched: isWatched
        case .history: inHistory
        }
    }
}

struct LibraryFilter {
    var segment: LibrarySegment
    var query: String = ""
    var mediaType: MediaType?

    static func entries(from items: [LibraryItem]) -> [LibraryEntry] {
        items.compactMap(LibraryEntry.init)
    }

    static func count(_ segment: LibrarySegment, in entries: [LibraryEntry]) -> Int {
        entries.filter { $0.isIn(segment) }.count
    }

    /// Mantém a ordem recebida.
    func apply(to entries: [LibraryEntry]) -> [LibraryEntry] {
        let needle = Self.normalize(query)
        return entries.filter { entry in
            guard entry.isIn(segment) else { return false }
            if let mediaType, entry.title.mediaType != mediaType { return false }
            guard !needle.isEmpty else { return true }
            return Self.normalize(entry.title.title).contains(needle)
                || Self.normalize(entry.title.originalTitle).contains(needle)
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FilmFinderTests/LibraryFilterTests 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`, 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add FilmFinder/Features/Library/LibraryFilter.swift FilmFinderTests/LibraryFilterTests.swift
git commit -m "feat(library): add LibraryFilter with segment, search and type filtering" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: LibraryStore removal per segment and undo

**Files:**
- Modify: `FilmFinder/Data/LibraryStore.swift` (add `LibraryFlags` above the class; add three methods before `func save()`)
- Test: `FilmFinderTests/LibraryStoreRemovalTests.swift` (new)

**Interfaces:**
- Consumes: `LibrarySegment` (Task 1).
- Produces:
  - `struct LibraryFlags: Equatable, Sendable { var isFavorite: Bool; var isWatched: Bool; var inHistory: Bool }`
  - `LibraryStore.flags(for title: Title) -> LibraryFlags?`
  - `LibraryStore.remove(_ title: Title, from segment: LibrarySegment)`
  - `LibraryStore.restore(_ flags: LibraryFlags, for title: Title)`

- [ ] **Step 1: Write the failing tests**

Create `FilmFinderTests/LibraryStoreRemovalTests.swift`:

```swift
import Foundation
import Testing
@testable import FilmFinder

@MainActor
@Suite struct LibraryStoreRemovalTests {
    private func seeded() throws -> (LibraryHarness, Title) {
        let h = try LibraryHarness()
        let title = Title.sample(id: 1)
        h.store.setFavorite(title, true)
        h.store.setWatched(title, true)
        h.store.markShown(title)
        return (h, title)
    }

    @Test func removeFromFavoritesKeepsOtherFlags() throws {
        let (h, title) = try seeded()
        h.store.remove(title, from: .favorites)

        let item = try #require(h.item(title.id))
        #expect(!item.isFavorite)
        #expect(item.isWatched)
        #expect(item.inHistory)
    }

    @Test func removeFromWatchedKeepsOtherFlags() throws {
        let (h, title) = try seeded()
        h.store.remove(title, from: .watched)

        let item = try #require(h.item(title.id))
        #expect(item.isFavorite)
        #expect(!item.isWatched)
        #expect(item.inHistory)
    }

    @Test func removeFromHistoryKeepsFavoriteAndWatched() throws {
        let (h, title) = try seeded()
        h.store.remove(title, from: .history)

        let item = try #require(h.item(title.id))
        #expect(item.isFavorite)
        #expect(item.isWatched)
        #expect(!item.inHistory)
    }

    @Test func restoreReappliesTheCapturedFlags() throws {
        let (h, title) = try seeded()
        let before = try #require(h.store.flags(for: title))
        h.store.remove(title, from: .history)
        h.store.remove(title, from: .favorites)
        h.store.restore(before, for: title)

        #expect(h.store.flags(for: title) == before)
    }

    @Test func flagsAreNilForUnknownTitle() throws {
        let h = try LibraryHarness()
        #expect(h.store.flags(for: .sample(id: 99)) == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FilmFinderTests/LibraryStoreRemovalTests 2>&1 | tail -30`
Expected: build FAIL, `value of type 'LibraryStore' has no member 'remove'`.

- [ ] **Step 3: Implement**

In `FilmFinder/Data/LibraryStore.swift`, add above `@MainActor final class LibraryStore`:

```swift
/// Estado dos marcadores de um título; guardado antes de uma remoção para poder desfazê-la.
struct LibraryFlags: Equatable, Sendable {
    var isFavorite: Bool
    var isWatched: Bool
    var inHistory: Bool
}
```

Add before `func save()`:

```swift
    func flags(for title: Title) -> LibraryFlags? {
        guard let item = fetch(key: title.id) else { return nil }
        return LibraryFlags(isFavorite: item.isFavorite, isWatched: item.isWatched, inHistory: item.inHistory)
    }

    /// Tira o título só do segmento indicado; os outros marcadores ficam como estão.
    func remove(_ title: Title, from segment: LibrarySegment) {
        switch segment {
        case .favorites: setFavorite(title, false)
        case .watched: setWatched(title, false)
        case .history: removeFromHistory(title)
        }
    }

    func restore(_ flags: LibraryFlags, for title: Title) {
        let item = upsert(title)
        item.isFavorite = flags.isFavorite
        item.isWatched = flags.isWatched
        item.inHistory = flags.inHistory
        save()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FilmFinderTests/LibraryStoreRemovalTests -only-testing:FilmFinderTests/LibraryStoreTests 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **` (new tests plus the existing store tests).

- [ ] **Step 5: Commit**

```bash
git add FilmFinder/Data/LibraryStore.swift FilmFinderTests/LibraryStoreRemovalTests.swift
git commit -m "feat(library): remove per segment and restore flags for undo" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Biblioteca screen and tab restructure

**Files:**
- Create: `FilmFinder/Features/Library/LibrarySegment+UI.swift`
- Create: `FilmFinder/Features/Library/UndoToast.swift`
- Create: `FilmFinder/Features/Library/LibraryGridCell.swift`
- Create: `FilmFinder/Features/Library/LibraryView.swift`
- Modify (rewrite): `FilmFinder/Features/Library/LibraryRow.swift`
- Modify (rewrite): `FilmFinder/Features/Home/MainView.swift`
- Delete: `FilmFinder/Features/Library/LibraryListView.swift`, `FilmFinder/Features/Library/HistoryView.swift`, `FilmFinder/Features/Profile/ProfileView.swift`, `FilmFinder/Features/Profile/LibraryPreviewRectangle.swift`

**Interfaces:**
- Consumes: `LibrarySegment`, `LibraryEntry`, `LibraryFilter` (Task 1); `LibraryStore.flags/remove/restore`, `LibraryFlags` (Task 2); existing `PosterImage(path:)`, `TitleDetail(title:)`, `MediaType.pluralName`, `LibraryStore.setFavorite/setWatched/clearHistory`.
- Produces: `enum AppTab { recommendations, library, settings }` and environment value `\.selectTab: @MainActor (AppTab) -> Void` (empty-state button uses it); `LibraryView`.

UI task: verified by building and running in the simulator rather than unit tests (the logic is already covered in Tasks 1–2).

- [ ] **Step 1: Segment presentation strings**

Create `FilmFinder/Features/Library/LibrarySegment+UI.swift`:

```swift
import SwiftUI

extension LibrarySegment {
    var title: LocalizedStringKey {
        switch self {
        case .favorites: "Favoritos"
        case .watched: "Assistidos"
        case .history: "Histórico"
        }
    }

    var emptyTitle: LocalizedStringKey {
        switch self {
        case .favorites: "Nada favoritado ainda"
        case .watched: "Nada assistido ainda"
        case .history: "Seu histórico está vazio"
        }
    }

    var emptyMessage: LocalizedStringKey {
        switch self {
        case .favorites: "Toque no coração de um título para guardá-lo aqui."
        case .watched: "Marque títulos como assistidos para acompanhá-los aqui."
        case .history: "Os títulos que o app recomendar aparecem aqui."
        }
    }

    var emptyIcon: String {
        switch self {
        case .favorites: "heart"
        case .watched: "eye"
        case .history: "clock.arrow.circlepath"
        }
    }

    var removedMessage: LocalizedStringKey {
        switch self {
        case .favorites: "Removido dos favoritos"
        case .watched: "Removido dos assistidos"
        case .history: "Removido do histórico"
        }
    }
}
```

- [ ] **Step 2: Undo toast**

Create `FilmFinder/Features/Library/UndoToast.swift`:

```swift
import SwiftUI

struct UndoToast: View {
    let message: LocalizedStringKey
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.branco)
            Spacer()
            Button("Desfazer", action: onUndo)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.laranja)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cinza2, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }
}
```

- [ ] **Step 3: Row and grid cell**

Replace the whole of `FilmFinder/Features/Library/LibraryRow.swift`:

```swift
import SwiftUI

struct LibraryRow: View {
    let entry: LibraryEntry

    var body: some View {
        NavigationLink {
            TitleDetail(title: entry.title)
        } label: {
            HStack(spacing: 12) {
                PosterImage(path: entry.title.posterPath)
                    .frame(width: 70, height: 105)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title.title)
                        .font(.system(size: 16, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.branco)
                    HStack(spacing: 8) {
                        if let year = entry.title.year {
                            Text(String(year))
                        }
                        Label(String(format: "%.1f", entry.title.rating), systemImage: "star.fill")
                            .foregroundColor(.laranja)
                        if let genre = entry.title.genres.first {
                            Text(genre)
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.branco)
                    Text(entry.date, style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                LibraryBadges(entry: entry)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Selos de favorito/assistido, usados na linha e na célula da grade.
struct LibraryBadges: View {
    let entry: LibraryEntry

    var body: some View {
        HStack(spacing: 4) {
            if entry.isFavorite {
                Image(systemName: "heart.fill").foregroundColor(.rosa)
            }
            if entry.isWatched {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.laranja)
            }
        }
        .font(.system(size: 14))
    }
}
```

Create `FilmFinder/Features/Library/LibraryGridCell.swift`:

```swift
import SwiftUI

struct LibraryGridCell: View {
    let entry: LibraryEntry

    var body: some View {
        NavigationLink {
            TitleDetail(title: entry.title)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay { PosterImage(path: entry.title.posterPath) }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        LibraryBadges(entry: entry)
                            .padding(6)
                            .shadow(color: .preto, radius: 3)
                    }
                Text(entry.title.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.branco)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let year = entry.title.year {
                    Text(String(year))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: LibraryView**

Create `FilmFinder/Features/Library/LibraryView.swift`:

```swift
import SwiftData
import SwiftUI

struct LibraryView: View {
    private enum Layout: String {
        case list
        case grid
    }

    private struct UndoState: Identifiable {
        let id = UUID()
        let message: LocalizedStringKey
        let perform: () -> Void
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectTab) private var selectTab
    @Query(
        filter: #Predicate<LibraryItem> { $0.isFavorite || $0.isWatched || $0.inHistory },
        sort: \.recommendedAt,
        order: .reverse
    )
    private var items: [LibraryItem]

    @State private var segment: LibrarySegment = .favorites
    @State private var query = ""
    @State private var mediaType: MediaType?
    @State private var undo: UndoState?
    @State private var confirmingClear = false
    @AppStorage("library.layout") private var layoutRaw = Layout.list.rawValue

    private var layout: Layout { Layout(rawValue: layoutRaw) ?? .list }

    var body: some View {
        let entries = LibraryFilter.entries(from: items)
        let visible = LibraryFilter(segment: segment, query: query, mediaType: mediaType).apply(to: entries)

        NavigationStack {
            VStack(spacing: 12) {
                header(entries)
                content(visible)
            }
            .background(Color.cinza1)
            .navigationTitle("Biblioteca")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Buscar na biblioteca")
            .toolbar { toolbar }
            .overlay(alignment: .bottom) { toast }
            .confirmationDialog("Limpar histórico?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Limpar histórico", role: .destructive) {
                    LibraryStore(context: modelContext).clearHistory()
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    // MARK: - Cabeçalho

    private func header(_ entries: [LibraryEntry]) -> some View {
        VStack(spacing: 10) {
            Text("\(LibraryFilter.count(.watched, in: entries)) assistidos · \(LibraryFilter.count(.favorites, in: entries)) favoritos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Picker("Segmento", selection: $segment) {
                ForEach(LibrarySegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                layoutRaw = (layout == .list ? Layout.grid : Layout.list).rawValue
            } label: {
                Image(systemName: layout == .list ? "square.grid.2x2" : "list.bullet")
            }
            .accessibilityLabel(layout == .list ? "Grade" : "Lista")

            Menu {
                Picker("Tipo", selection: $mediaType) {
                    Text("Todos").tag(MediaType?.none)
                    ForEach(MediaType.allCases, id: \.self) { type in
                        Text(type.pluralName).tag(MediaType?.some(type))
                    }
                }
                if segment == .history {
                    Divider()
                    Button("Limpar histórico", role: .destructive) { confirmingClear = true }
                }
            } label: {
                Image(systemName: mediaType == nil ? "ellipsis.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private func content(_ visible: [LibraryEntry]) -> some View {
        if visible.isEmpty {
            emptyState
        } else if layout == .grid {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 16) {
                    ForEach(visible) { entry in
                        LibraryGridCell(entry: entry)
                            .contextMenu {
                                toggles(for: entry)
                                removeButton(for: entry)
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
        } else {
            List(visible) { entry in
                LibraryRow(entry: entry)
                    .listRowBackground(Color.cinza1)
                    .swipeActions(edge: .leading) { toggles(for: entry) }
                    .swipeActions(edge: .trailing) { removeButton(for: entry) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty || mediaType != nil {
            ContentUnavailableView(
                "Nenhum resultado",
                systemImage: "magnifyingglass",
                description: Text("Tente outro termo ou filtro.")
            )
        } else {
            ContentUnavailableView {
                Label(segment.emptyTitle, systemImage: segment.emptyIcon)
            } description: {
                Text(segment.emptyMessage)
            } actions: {
                Button("Ir para Recomendações") { selectTab(.recommendations) }
                    .buttonStyle(.borderedProminent)
                    .tint(.laranja)
            }
        }
    }

    // MARK: - Ações

    @ViewBuilder
    private func toggles(for entry: LibraryEntry) -> some View {
        Button { toggleFavorite(entry) } label: {
            Label(entry.isFavorite ? "Desfavoritar" : "Favoritar", systemImage: entry.isFavorite ? "heart.slash" : "heart")
        }
        .tint(.rosa)
        Button { toggleWatched(entry) } label: {
            Label(entry.isWatched ? "Não assistido" : "Assistido", systemImage: entry.isWatched ? "eye.slash" : "eye")
        }
        .tint(.roxo)
    }

    private func removeButton(for entry: LibraryEntry) -> some View {
        Button(role: .destructive) { remove(entry) } label: {
            Label("Remover", systemImage: "trash")
        }
    }

    private func toggleFavorite(_ entry: LibraryEntry) {
        withAnimation { LibraryStore(context: modelContext).setFavorite(entry.title, !entry.isFavorite) }
    }

    private func toggleWatched(_ entry: LibraryEntry) {
        withAnimation { LibraryStore(context: modelContext).setWatched(entry.title, !entry.isWatched) }
    }

    private func remove(_ entry: LibraryEntry) {
        let store = LibraryStore(context: modelContext)
        guard let before = store.flags(for: entry.title) else { return }
        let removedFrom = segment
        withAnimation { store.remove(entry.title, from: removedFrom) }
        showUndo(removedFrom.removedMessage) {
            withAnimation { LibraryStore(context: modelContext).restore(before, for: entry.title) }
        }
    }

    // MARK: - Desfazer

    @ViewBuilder
    private var toast: some View {
        if let undo {
            UndoToast(message: undo.message) {
                undo.perform()
                withAnimation { self.undo = nil }
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showUndo(_ message: LocalizedStringKey, perform: @escaping () -> Void) {
        let state = UndoState(message: message, perform: perform)
        withAnimation { undo = state }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if undo?.id == state.id {
                withAnimation { undo = nil }
            }
        }
    }
}
```

- [ ] **Step 5: MainView with three tabs**

Replace the whole of `FilmFinder/Features/Home/MainView.swift`:

```swift
import SwiftUI

enum AppTab: Hashable {
    case recommendations
    case library
    case settings
}

extension EnvironmentValues {
    /// Permite a telas internas (ex.: estado vazio da Biblioteca) trocarem de aba.
    @Entry var selectTab: @MainActor (AppTab) -> Void = { _ in }
}

struct MainView: View {
    @State private var selectedTab: AppTab = .recommendations

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Label("Recomendações", systemImage: "magnifyingglass.circle.fill")
                }
                .tag(AppTab.recommendations)

            LibraryView()
                .tabItem {
                    Label("Biblioteca", systemImage: "books.vertical.fill")
                }
                .tag(AppTab.library)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .accentColor(Color.laranja)
        .environment(\.selectTab) { selectedTab = $0 }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
```

- [ ] **Step 6: Delete the old screens**

```bash
git rm FilmFinder/Features/Library/LibraryListView.swift FilmFinder/Features/Library/HistoryView.swift FilmFinder/Features/Profile/ProfileView.swift FilmFinder/Features/Profile/LibraryPreviewRectangle.swift
grep -rn "LibraryListView\|HistoryView\|ProfileView\|LibraryPreviewRectangle" FilmFinder FilmFinderTests
```
Expected: `grep` prints nothing. If it prints a reference, update that file to use `LibraryView` / remove the reference.

- [ ] **Step 7: Build and run all tests**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`. If Swift 6 reports a Sendable/isolation error on the `@Entry` default closure or the `Task` in `showUndo`, fix it by keeping the `@MainActor` annotation on the closure type and capturing only `state`/`undo` ids (do not loosen to `@unchecked Sendable`).

- [ ] **Step 8: Verify in the simulator**

Use `mcp__Claude_Code_iOS_Simulator__control` (`attach` first, then `build` + `launch`). Check:
1. The tab bar shows three tabs: Recomendações, Biblioteca, Ajustes.
2. Biblioteca on a fresh install shows the empty state per segment (Favoritos/Assistidos/Histórico) and "Ir para Recomendações" switches to the first tab.
3. After getting a recommendation and favoriting a title: it appears under Favoritos; swipe right shows Favoritar/Assistido, swipe left Remover; removing shows the "Desfazer" toast, and tapping it restores the row.
4. Search "<part of the title without accents>" filters; a term with no match shows "Nenhum resultado"; the type filter and the list/grid toggle work, and the layout survives an app relaunch.
5. In Histórico, the menu's "Limpar histórico" asks for confirmation.
Take screenshots of the list, grid and an empty state.

- [ ] **Step 9: Commit**

```bash
git add -A FilmFinder
git commit -m "feat(library): unified Biblioteca tab with search, filter, grid, swipe actions and undo" -m "Replaces the Histórico and Perfil tabs." -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Ajustes header card

**Files:**
- Modify: `FilmFinder/Domain/Recommendation.swift` (add `Quota.usedFraction`)
- Create: `FilmFinder/Features/Settings/QuotaCard.swift`
- Modify: `FilmFinder/Features/Settings/SettingsView.swift`
- Test: `FilmFinderTests/QuotaTests.swift`

**Interfaces:**
- Produces: `Quota.usedFraction: Double` (0...1); `QuotaCard(quota: Quota?, isSignedIn: Bool)`.

- [ ] **Step 1: Write the failing test**

Create `FilmFinderTests/QuotaTests.swift`:

```swift
import Foundation
import Testing
@testable import FilmFinder

@Suite struct QuotaTests {
    @Test func usedFractionIsTheShareOfTheLimit() {
        #expect(Quota(used: 3, limit: 10, resetsAt: Date()).usedFraction == 0.3)
    }

    @Test func usedFractionIsClampedToOne() {
        #expect(Quota(used: 12, limit: 10, resetsAt: Date()).usedFraction == 1)
    }

    @Test func usedFractionIsZeroWhenLimitIsZero() {
        #expect(Quota(used: 0, limit: 0, resetsAt: Date()).usedFraction == 0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodegen generate && xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FilmFinderTests/QuotaTests 2>&1 | tail -30`
Expected: build FAIL, `value of type 'Quota' has no member 'usedFraction'`.

- [ ] **Step 3: Implement `usedFraction`**

In `FilmFinder/Domain/Recommendation.swift`, inside `struct Quota`, after `var remaining`:

```swift
    var usedFraction: Double {
        limit > 0 ? min(1, Double(used) / Double(limit)) : 0
    }
```

- [ ] **Step 4: Run to verify it passes**

Run: same command as Step 2. Expected: `** TEST SUCCEEDED **`, 3 tests.

- [ ] **Step 5: Card view**

Create `FilmFinder/Features/Settings/QuotaCard.swift`:

```swift
import SwiftUI

struct QuotaCard: View {
    let quota: Quota?
    let isSignedIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Buscas de hoje", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.laranja)
                Spacer()
                if let quota {
                    Text("\(quota.remaining) restantes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let quota {
                ProgressView(value: quota.usedFraction)
                    .tint(.laranja)
                Text("Renova \(quota.resetsAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            Divider()

            Label(
                isSignedIn ? "Conectado com a Apple" : "Sem conta conectada",
                systemImage: isSignedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark"
            )
            .font(.subheadline)
            .foregroundColor(isSignedIn ? .laranja : .secondary)
        }
        .padding()
        .background(Color.cinza2, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 6: Wire it into SettingsView**

In `FilmFinder/Features/Settings/SettingsView.swift`:

Replace
```swift
            List {
                accountSection
                searchesSection
                aboutSection
            }
```
with
```swift
            List {
                Section {
                    QuotaCard(quota: account.quota, isSignedIn: account.isSignedIn)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                accountSection
                aboutSection
            }
```

Remove the duplicated status row from `accountSection` (the card now shows it). Delete these two lines:
```swift
                Label("Conectado com a Apple", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.laranja)
```

Delete the whole `// MARK: - Buscas` block, i.e. the `searchesSection` property:
```swift
    // MARK: - Buscas

    private var searchesSection: some View {
        Section("Buscas") {
            if let quota = account.quota {
                Text("\(quota.remaining) de \(quota.limit) buscas restantes hoje")
            } else {
                Text("Carregando…")
                    .foregroundStyle(.secondary)
            }
        }
    }

```

- [ ] **Step 7: Build, test, check in the simulator**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`.
Then in the simulator, open Ajustes: the card shows quota bar and account status at the top; Conta (Sair/Excluir or Sign in with Apple) and Sobre are unchanged. Take a screenshot.

- [ ] **Step 8: Commit**

```bash
git add -A FilmFinder FilmFinderTests
git commit -m "feat(settings): quota and account header card" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: English translations and final check

**Files:**
- Modify: `FilmFinder/Localizable.xcstrings`

- [ ] **Step 1: Add the missing `en` entries**

Run this script from the repo root (it only adds keys that do not exist yet and keeps Xcode's `" : "` formatting so the diff stays small):

```bash
python3 - <<'EOF'
import json
path = "FilmFinder/Localizable.xcstrings"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

new = {
    "Biblioteca": "Library",
    "Buscar na biblioteca": "Search library",
    "%lld assistidos · %lld favoritos": "%lld watched · %lld favorites",
    "Segmento": "Segment",
    "Tipo": "Type",
    "Todos": "All",
    "Grade": "Grid",
    "Lista": "List",
    "Nada favoritado ainda": "No favorites yet",
    "Nada assistido ainda": "Nothing watched yet",
    "Seu histórico está vazio": "Your history is empty",
    "Toque no coração de um título para guardá-lo aqui.": "Tap the heart on a title to keep it here.",
    "Marque títulos como assistidos para acompanhá-los aqui.": "Mark titles as watched to track them here.",
    "Os títulos que o app recomendar aparecem aqui.": "Titles the app recommends show up here.",
    "Removido dos favoritos": "Removed from favorites",
    "Removido dos assistidos": "Removed from watched",
    "Removido do histórico": "Removed from history",
    "Desfazer": "Undo",
    "Nenhum resultado": "No results",
    "Tente outro termo ou filtro.": "Try another term or filter.",
    "Ir para Recomendações": "Go to Recommendations",
    "Limpar histórico": "Clear history",
    "Limpar histórico?": "Clear history?",
    "Favoritar": "Favorite",
    "Desfavoritar": "Unfavorite",
    "Assistido": "Watched",
    "Não assistido": "Not watched",
    "Remover": "Remove",
    "Buscas de hoje": "Today's searches",
    "%lld restantes": "%lld left",
    "Renova %@": "Resets %@",
    "Sem conta conectada": "No account connected",
}
added = []
for key, en in new.items():
    if key in data["strings"]:
        continue
    data["strings"][key] = {"localizations": {"en": {"stringUnit": {"state": "translated", "value": en}}}}
    added.append(key)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, separators=(",", " : "))
    f.write("\n")
print("added:", len(added))
EOF
git diff --stat FilmFinder/Localizable.xcstrings
```
Expected: `added:` is between 20 and 31 (some keys already exist), and the diff stat shows only insertions (a handful of deletions at most). If the diff rewrites the whole file, restore with `git checkout FilmFinder/Localizable.xcstrings` and add the entries by hand in Xcode's String Catalog editor instead.

- [ ] **Step 2: Full test run and build**

Run: `xcodebuild test -project FilmFinder.xcodeproj -scheme FilmFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: English spot check in the simulator**

Launch the app with English language (`xcrun simctl launch booted com.andre.filmfinder -AppleLanguages "(en)"`) and confirm Biblioteca shows "Library", the segments "Favorites / Watched / History", the empty states and the toast in English.

- [ ] **Step 4: Commit**

```bash
git add FilmFinder/Localizable.xcstrings
git commit -m "chore(i18n): English strings for the library and settings redesign" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage**
- Tab structure 4 → 3, old screens removed: Task 3 (Steps 5–6).
- Cabeçalho com contadores, seletor, busca, filtro de tipo, toggle lista/grade (`@AppStorage`): Task 3 Step 4.
- `LibraryFilter` puro, busca sem caixa/acento em `title` e `originalTitle`, snapshot inválido ignorado: Task 1.
- Swipe (esquerda remove, direita alterna favorito/assistido), menu de contexto na grade: Task 3 Step 4.
- Remoção por segmento sem afetar os outros marcadores + desfazer: Task 2 + Task 3 (`remove`/`showUndo`).
- Limpar histórico com confirmação: Task 3 (toolbar menu + `confirmationDialog`).
- Estados vazios por segmento + botão para Recomendações; "Nenhum resultado" distinto: Task 3 (`emptyState`, `selectTab`).
- Linha com nota/gênero, célula de grade com selos: Task 3 Step 3.
- Ajustes: card de cota com barra e estado da conta, substitui seção "Buscas": Task 4.
- Testes (filtro, remoção, desfazer) e verificação visual: Tasks 1, 2, 3 Step 8, 4 Step 7.
- Strings em `Localizable.xcstrings`: Task 5.

**Placeholders:** none; every code step has full code.

**Type consistency:** `LibrarySegment`, `LibraryEntry`, `LibraryFilter(segment:query:mediaType:)`, `LibraryFilter.entries(from:)`, `LibraryFilter.count(_:in:)` (Task 1) match their uses in Tasks 2–3; `LibraryFlags`, `flags(for:)`, `remove(_:from:)`, `restore(_:for:)` (Task 2) match `LibraryView.remove`; `AppTab`/`selectTab` defined and consumed in Task 3; `Quota.usedFraction` and `QuotaCard(quota:isSignedIn:)` defined and used in Task 4.
