import Foundation

#if canImport(Photos)
@available(iOS 26.1, *)
/// Ephemeral `BackgroundUploadJobStore` useful for previews and testing.
public actor InMemoryBackgroundUploadJobStore: BackgroundUploadJobStore {
    private var storage: [String: BackgroundUploadJobState] = [:]

    public init() {}

    public func loadState(for jobIdentifier: String) async -> BackgroundUploadJobState? {
        storage[jobIdentifier]
    }

    public func record(_ state: BackgroundUploadJobState) async {
        storage[state.jobIdentifier] = state
    }

    public func reset(jobIdentifier: String) async {
        storage.removeValue(forKey: jobIdentifier)
    }
}
#endif
