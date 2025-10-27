#if os(iOS)
import PhotoBackgroundUploadKit

@available(iOS 26.1, *)
final class BackgroundUploadExtension: PHBackgroundResourceUploadExtension {
    private lazy var handler = makeDefaultHandler()

    override func process(_ job: PHAssetResourceUploadJob) async -> PHBackgroundResourceUploadProcessingResult {
        await handler.process(job: job)
    }
}
#endif
