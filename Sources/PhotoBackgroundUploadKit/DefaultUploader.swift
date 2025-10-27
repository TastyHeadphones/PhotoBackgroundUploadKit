import Foundation

#if canImport(Photos)
@available(iOS 26.1, *)
/// Default implementation that coordinates resource extraction, transport uploads, and retry recording.
public final class DefaultBackgroundUploader: BackgroundUploader {
    private let transport: any BackgroundUploadTransport
    private let jobStore: any BackgroundUploadJobStore
    private let resourceProvider: any BackgroundUploadResourceProvider
    private let logger: BackgroundUploadLogger

    public init(
        transport: any BackgroundUploadTransport,
        jobStore: any BackgroundUploadJobStore,
        resourceProvider: any BackgroundUploadResourceProvider,
        logger: BackgroundUploadLogger
    ) {
        self.transport = transport
        self.jobStore = jobStore
        self.resourceProvider = resourceProvider
        self.logger = logger
    }

    public func process(job: PHAssetResourceUploadJob, configuration: BackgroundUploadConfiguration) async -> PHBackgroundResourceUploadProcessingResult {
        let jobId = job.localIdentifier
        let previousState = await jobStore.loadState(for: jobId)
        let attempts: Int
        switch previousState?.status {
        case let .inProgress(existingAttempts):
            attempts = existingAttempts + 1
        case .failed, .pending, .completed, .none:
            attempts = 1
        }
        let context = BackgroundUploadJobContext(job: job, attempt: attempts)
        await jobStore.record(
            .init(jobIdentifier: jobId, status: .inProgress(attempts: attempts))
        )
        logger.log(.info, "Processing job \(jobId) (attempt \(attempts))")

        do {
            let resources = try await resourceProvider.resources(for: job, configuration: configuration)
            for resource in resources {
                logger.log(.info, "Uploading resource \(resource.jobIdentifier) for asset \(resource.assetIdentifier)")
                _ = try await transport.upload(
                    job: context,
                    resource: resource,
                    configuration: configuration
                )
            }
            await jobStore.record(.init(jobIdentifier: jobId, status: .completed))
            logger.log(.info, "Job \(jobId) finished")
            return .finished
        } catch {
            let delay = configuration.retryPolicy.delay(for: attempts) ?? 0
            await jobStore.record(.init(jobIdentifier: jobId, status: .failed(AnySendable(error))))
            logger.log(.error, "Job \(jobId) failed with error: \(error)")
            if delay <= 0 {
                return .failure(error)
            } else {
                return .retry(after: delay)
            }
        }
    }
}
#if canImport(Photos)
@available(iOS 26.1, *)
extension DefaultBackgroundUploader: @unchecked Sendable {}
#endif
#endif
