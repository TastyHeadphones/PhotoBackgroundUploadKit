import Foundation
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)
@available(iOS 26.1, *)
@MainActor
/// Entry point for host apps to prepare `PHAssetResourceUploadJob` instances and push shared configuration to the extension.
public final class PhotoBackgroundUploadManager {
    public let configuration: BackgroundUploadConfiguration
    private var pipelineFactory: any BackgroundUploadPipelineFactory
    private let scheduler: BackgroundUploadScheduler

    /// Creates a manager with default components ready to be shared across the host app.
    public init(
        configuration: BackgroundUploadConfiguration,
        pipelineFactory: any BackgroundUploadPipelineFactory = DefaultBackgroundUploadPipelineFactory()
    ) {
        self.configuration = configuration
        self.pipelineFactory = pipelineFactory
        let pipeline = pipelineFactory.makePipeline(configuration: configuration)
        self.scheduler = BackgroundUploadScheduler(
            configuration: configuration,
            logger: pipeline.logger
        )
        if #available(iOS 26.1, macOS 10.15, *) {
            Task { [configuration, pipelineFactory] in
                await BackgroundUploadExtensionBridge.shared.register(pipelineFactory: pipelineFactory)
                await BackgroundUploadExtensionBridge.shared.updatePipeline(configuration: configuration)
            }
        }
    }

    /// Enqueues background upload jobs for the provided asset identifiers using `PHAssetResourceUploadJobChangeRequest`.
    /// The default implementation applies sensible values based on ``BackgroundUploadConfiguration`` while allowing callers
    /// to further customize the underlying `PHAssetResourceUploadJobChangeRequest`.
    @discardableResult
    public func enqueueAssets(
        _ assetIdentifiers: [String],
        userInfo: [String: AnySendable] = [:],
        customize: ((PHAssetResourceUploadJobChangeRequest) -> Void)? = nil
    ) async throws -> [BackgroundUploadJobDescriptor] {
        try await scheduler.enqueueAssets(
            assetIdentifiers,
            userInfo: userInfo,
            customize: customize
        )
    }

    /// Pushes the latest configuration into ``BackgroundUploadExtensionBridge``.
    /// Invoke when host-side settings change to keep the upload extension in sync.
    public func synchronizeExtensionPipeline() {
        let configuration = configuration
        let pipelineFactory = pipelineFactory
        if #available(iOS 26.1, macOS 10.15, *) {
            Task { [configuration, pipelineFactory] in
                await BackgroundUploadExtensionBridge.shared.register(pipelineFactory: pipelineFactory)
                await BackgroundUploadExtensionBridge.shared.updatePipeline(configuration: configuration)
            }
        }
    }

    /// Replaces the current pipeline factory, allowing callers to swap dependencies at runtime.
    public func updatePipelineFactory(_ factory: any BackgroundUploadPipelineFactory) {
        pipelineFactory = factory
        synchronizeExtensionPipeline()
    }
}
#endif
