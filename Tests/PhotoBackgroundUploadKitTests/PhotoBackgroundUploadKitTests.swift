import XCTest
@testable import PhotoBackgroundUploadKit

@MainActor
final class PhotoBackgroundUploadKitTests: XCTestCase {
    func testUploaderCompletesWithShimResources() async throws {
        let configuration = BackgroundUploadConfiguration(
            extensionBundleIdentifier: "com.example.extension",
            transportIdentifier: "mock.transport",
            retryPolicy: .exponentialBackoff(initial: 0.5, multiplier: 2, maximum: 3)
        )

        let transport = MockTransport(result: .success)
        let jobStore = InMemoryBackgroundUploadJobStore()
        let resourceProvider = PhotoKitBackgroundUploadResourceProvider()
        let logger = BackgroundUploadLogger { _, _ in }

        let uploader = DefaultBackgroundUploader(
            transport: transport,
            jobStore: jobStore,
            resourceProvider: resourceProvider,
            logger: logger
        )

        let job = PHAssetResourceUploadJob(
            assetLocalIdentifier: "FAKE-ASSET-1",
            userInfo: [
                "resources": [
                    ShimUploadResource(
                        type: .photo,
                        filename: "image.jpg",
                        data: Data("demo".utf8)
                    )
                ]
            ],
            requestedResourceTypes: [.photo]
        )

        let result = await uploader.process(job: job, configuration: configuration)

        if case .finished = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected finished result, got \(result)")
        }

        let stored = await jobStore.loadState(for: job.localIdentifier)
        if case .completed = stored?.status {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected completed job state")
        }

        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testUploaderRetriesWithConfiguredDelay() async throws {
        let configuration = BackgroundUploadConfiguration(
            extensionBundleIdentifier: "com.example.extension",
            transportIdentifier: "mock.transport",
            retryPolicy: .exponentialBackoff(initial: 2, multiplier: 2, maximum: 10)
        )

        let transport = MockTransport(result: .failure(MockError.uploadFailed))
        let jobStore = InMemoryBackgroundUploadJobStore()
        let resourceProvider = PhotoKitBackgroundUploadResourceProvider()
        let logger = BackgroundUploadLogger { _, _ in }

        let uploader = DefaultBackgroundUploader(
            transport: transport,
            jobStore: jobStore,
            resourceProvider: resourceProvider,
            logger: logger
        )

        let job = PHAssetResourceUploadJob(
            assetLocalIdentifier: "FAKE-ASSET-2",
            userInfo: [
                "resources": [
                    ShimUploadResource(
                        type: .video,
                        filename: "clip.mov",
                        data: Data("video".utf8)
                    )
                ]
            ],
            requestedResourceTypes: [.video]
        )

        let result = await uploader.process(job: job, configuration: configuration)

        switch result {
        case let .retry(after):
            XCTAssertEqual(after, 2, accuracy: 0.001)
        default:
            XCTFail("Expected retry result, got \(result)")
        }

        let stored = await jobStore.loadState(for: job.localIdentifier)
        if case let .failed(errorBox) = stored?.status {
            XCTAssertEqual(errorBox.value as? MockError, .uploadFailed)
        } else {
            XCTFail("Expected failed job state")
        }
    }
}

// MARK: - Test Doubles

private struct MockTransport: BackgroundUploadTransport {
    enum Outcome {
        case success
        case failure(Error)
    }

    let result: Outcome
    private(set) var callCount: Int = 0

    func upload(
        job: BackgroundUploadJobContext,
        resource: BackgroundUploadResourceContext,
        configuration: BackgroundUploadConfiguration
    ) async throws -> BackgroundUploadResponse {
        await incrementCallCount()
        switch result {
        case .success:
            return BackgroundUploadResponse(outcome: .completed(nil))
        case let .failure(error):
            throw error
        }
    }

    private func incrementCallCount() async {
        await callCounter.increment()
    }

    private let callCounter = Counter()

    final actor Counter {
        private var value: Int = 0

        func increment() {
            value += 1
        }

        func current() -> Int {
            value
        }
    }

    func callCount() async -> Int {
        await callCounter.current()
    }
}

private enum MockError: Error, Equatable {
    case uploadFailed
}
