import Foundation
import SwiftUI
import Combine

@MainActor
public final class ConversationSearchViewModel: ObservableObject {
    @Published public var searchText: String = ""
    @Published public var results: [ConversationSearchResult] = []
    @Published public var isSearching: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var activeSearchTask: Task<Void, Never>?
    private let searchService: ConversationSearchService
    
    public init(searchService: ConversationSearchService = .shared) {
        self.searchService = searchService
    }
    
    /// Configures the debounced search pipeline listening to `searchText` updates.
    public func setupSearchPipeline(sessionsProvider: @escaping () -> [ChatSession]) {
        cancellables.removeAll()
        
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                self.performSearch(query: query, sessions: sessionsProvider())
            }
            .store(in: &cancellables)
    }
    
    /// Executes the search operation asynchronously with cancellation of any pending search.
    public func performSearch(query: String, sessions: [ChatSession]) {
        activeSearchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        activeSearchTask = Task {
            let found = await searchService.search(query: trimmed, sessions: sessions)
            if !Task.isCancelled {
                self.results = found
                self.isSearching = false
            }
        }
    }
    
    /// Resets the search text and result set immediately.
    public func clearSearch() {
        activeSearchTask?.cancel()
        searchText = ""
        results = []
        isSearching = false
    }
}
