import Foundation
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)
@available(iOS 26.1, *)
/// Internal singleton that bridges configuration and components between the host process and its extension.
actor BackgroundUploadExtensionBridge {
    static let shared = BackgroundUploadExtensionBridge()

    private var pipelineFactory: (any BackgroundUploadPipelineFactory)?
    private var cachedPipeline: BackgroundUploadPipeline?
    private var configuration: BackgroundUploadConfiguration?

    func register(pipelineFactory: any BackgroundUploadPipelineFactory) {
        self.pipelineFactory = pipelineFactory
        if let configuration {
            cachedPipeline = pipelineFactory.makePipeline(configuration: configuration)
        }
    }

    func updatePipeline(configuration: BackgroundUploadConfiguration) {
        self.configuration = configuration
        if let pipelineFactory {
            cachedPipeline = pipelineFactory.makePipeline(configuration: configuration)
        }
    }

    func resolve() -> (BackgroundUploadPipeline, BackgroundUploadConfiguration)? {
        guard let configuration else { return nil }
        if cachedPipeline == nil, let pipelineFactory {
            cachedPipeline = pipelineFactory.makePipeline(configuration: configuration)
        }
        guard let pipeline = cachedPipeline else { return nil }
        return (pipeline, configuration)
    }

    func resources(for job: PHAssetResourceUploadJob) async throws -> [BackgroundUploadResourceContext] {
        guard let configuration else {
            throw BackgroundUploadError.resourcesMissing
        }
        if cachedPipeline == nil, let pipelineFactory {
            cachedPipeline = pipelineFactory.makePipeline(configuration: configuration)
        }
        guard let pipeline = cachedPipeline else {
            throw BackgroundUploadError.resourcesMissing
        }
        return try await pipeline.resourceProvider.resources(for: job, configuration: configuration)
    }
}

@available(iOS 26.1, *)
/// Convenience entry point for `PHBackgroundResourceUploadExtension` subclasses to run uploads with sensible defaults.
public final class BackgroundUploadExtensionHandler {
    private let fallbackConfiguration: BackgroundUploadConfiguration?
    private let fallbackFactory: (any BackgroundUploadPipelineFactory)?

    public init(
        configuration: BackgroundUploadConfiguration? = nil,
        pipelineFactory: (any BackgroundUploadPipelineFactory)? = nil
    ) {
        self.fallbackConfiguration = configuration
        self.fallbackFactory = pipelineFactory
    }

    public func process(job: PHAssetResourceUploadJob) async -> PHBackgroundResourceUploadProcessingResult {
        if let resolved = await BackgroundUploadExtensionBridge.shared.resolve() {
            let (pipeline, configuration) = resolved
            return await pipeline.uploader.process(job: job, configuration: configuration)
        } else if let configuration = fallbackConfiguration {
            let factory = fallbackFactory ?? DefaultBackgroundUploadPipelineFactory()
            let pipeline = factory.makePipeline(configuration: configuration)
            return await pipeline.uploader.process(job: job, configuration: configuration)
        } else {
            return .retry(after: 60)
        }
    }
}

@available(iOS 26.1, *)
public extension PHBackgroundResourceUploadExtension {
    func makeDefaultHandler(
        configuration: BackgroundUploadConfiguration? = nil,
        pipelineFactory: (any BackgroundUploadPipelineFactory)? = nil
    ) -> BackgroundUploadExtensionHandler {
        BackgroundUploadExtensionHandler(
            configuration: configuration,
            pipelineFactory: pipelineFactory
        )
    }
}
#endif
