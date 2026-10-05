import Foundation
import Observation

@MainActor
@Observable
final class ResultsModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(APIError)
    }

    static let visibleCount = 3

    let mediaType: MediaType
    let query: String

    private(set) var phase: Phase = .idle
    private(set) var visible: [Title] = []
    private(set) var buffer: [Title] = []
    private(set) var isSwapping = false
    private(set) var swapError: APIError?

    private let service: any RecommendationService
    private let store: LibraryStore
    private let localeInfo: LocaleInfo
    private let onQuota: (@MainActor (Quota) -> Void)?

    init(
        mediaType: MediaType,
        query: String,
        service: any RecommendationService,
        store: LibraryStore,
        localeInfo: LocaleInfo = LocaleInfo(),
        onQuota: (@MainActor (Quota) -> Void)? = nil
    ) {
        self.mediaType = mediaType
        self.query = query
        self.service = service
        self.store = store
        self.localeInfo = localeInfo
        self.onQuota = onQuota
    }

    /// Busca inicial. Só age no estado `.idle` (a view pode chamar de novo ao reaparecer).
    func load() async {
        guard phase == .idle else { return }
        phase = .loading
        do {
            let titles = try await fetch()
            guard !titles.isEmpty else {
                phase = .empty
                return
            }
            visible = Array(titles.prefix(Self.visibleCount))
            buffer = Array(titles.dropFirst(Self.visibleCount))
            visible.forEach { store.markShown($0) }
            phase = .loaded
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(Self.apiError(from: error))
        }
    }

    func retry() async {
        phase = .idle
        await load()
    }

    /// Troca um card pelo próximo do buffer; sem buffer, faz uma nova busca (consome cota no servidor).
    func swap(_ title: Title) async {
        guard !isSwapping, let index = visible.firstIndex(of: title) else { return }
        isSwapping = true
        swapError = nil
        defer { isSwapping = false }

        if buffer.isEmpty {
            do {
                buffer = try await fetch()
            } catch is CancellationError {
                return
            } catch {
                swapError = Self.apiError(from: error)
                return
            }
        }
        guard !buffer.isEmpty else { return }
        let next = buffer.removeFirst()
        visible[index] = next
        store.markShown(next)
    }

    private func fetch() async throws -> [Title] {
        let request = RecommendationRequest(
            query: query,
            mediaType: mediaType,
            excludeTmdbIds: store.excludedIDs(for: mediaType),
            locale: localeInfo.locale,
            region: localeInfo.region
        )
        let response = try await service.recommend(request)
        if let quota = response.quota { onQuota?(quota) }
        let titles = response.titles
        let onScreen = Set(visible.map(\.id))
        let fresh = titles.filter { !onScreen.contains($0.id) }
        store.recordRecommended(fresh)
        return fresh
    }

    private static func apiError(from error: Error) -> APIError {
        (error as? APIError) ?? .server(error.localizedDescription)
    }
}
