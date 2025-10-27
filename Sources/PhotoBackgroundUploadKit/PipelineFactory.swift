import Foundation
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)
@available(iOS 26.1, *)
/// Default factory that wires together the built-in transport, job store, resource provider, and uploader.
public struct DefaultBackgroundUploadPipelineFactory: BackgroundUploadPipelineFactory {
    private let session: URLSession
    private let createLogger: @Sendable () -> BackgroundUploadLogger

    public init(
        session: URLSession = .shared,
        logger: @escaping @Sendable () -> BackgroundUploadLogger = { BackgroundUploadLogger() }
    ) {
        self.session = session
        self.createLogger = logger
    }

    public func makePipeline(configuration: BackgroundUploadConfiguration) -> BackgroundUploadPipeline {
        let logger = createLogger()
        let transport = URLSessionBackgroundUploadTransport(session: session)
        let jobStore = InMemoryBackgroundUploadJobStore()
        let resourceProvider = PhotoKitBackgroundUploadResourceProvider()
        let uploader = DefaultBackgroundUploader(
            transport: transport,
            jobStore: jobStore,
            resourceProvider: resourceProvider,
            logger: logger
        )
        return BackgroundUploadPipeline(
            logger: logger,
            transport: transport,
            jobStore: jobStore,
            resourceProvider: resourceProvider,
            uploader: uploader
        )
    }
}
#endif
