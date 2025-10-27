import Foundation
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)
// MARK: - Configuration

@available(iOS 26.1, *)
/// Type-erased box that marks any underlying value as `Sendable` for cross-actor messaging.
public struct AnySendable: @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }
}

@available(iOS 26.1, *)
/// End-to-end configuration shared between the host app and its `PHBackgroundResourceUploadExtension`.
/// Values are propagated into each `PHAssetResourceUploadJobChangeRequest` created by ``PhotoBackgroundUploadManager``
/// and forwarded to the extension via ``BackgroundUploadExtensionBridge``.
public struct BackgroundUploadConfiguration: Sendable {
    /// Bundle identifier of the background upload extension that receives jobs created by the host app.
    public var extensionBundleIdentifier: String
    /// Identifier of the preferred transport implementation. Used to route jobs when multiple transports are registered.
    public var transportIdentifier: String
    /// Determines whether uploads may use cellular data. Applied via `PHAssetResourceUploadJobChangeRequest`.
    public var allowsCellularAccess: Bool
    /// Determines whether the job should be marked as high priority.
    public var isUserInitiated: Bool
    /// Optional custom metadata forwarded to the extension process via `PHAssetResourceUploadJob.userInfo`.
    public var defaultUserInfo: [String: AnySendable]
    /// Maximum number of resources fetched concurrently per job.
    public var maximumConcurrentUploads: Int
    /// Retry strategy applied when the transport throws.
    public var retryPolicy: BackgroundUploadRetryPolicy

    public init(
        extensionBundleIdentifier: String,
        transportIdentifier: String = "default.transport",
        allowsCellularAccess: Bool = true,
        isUserInitiated: Bool = false,
        defaultUserInfo: [String: AnySendable] = [:],
        maximumConcurrentUploads: Int = 2,
        retryPolicy: BackgroundUploadRetryPolicy = .exponentialBackoff()
    ) {
        self.extensionBundleIdentifier = extensionBundleIdentifier
        self.transportIdentifier = transportIdentifier
        self.allowsCellularAccess = allowsCellularAccess
        self.isUserInitiated = isUserInitiated
        self.defaultUserInfo = defaultUserInfo
        self.maximumConcurrentUploads = max(1, maximumConcurrentUploads)
        self.retryPolicy = retryPolicy
    }
}

@available(iOS 26.1, *)
public enum BackgroundUploadError: Error, Sendable {
    case assetNotFound
    case resourcesMissing
    case unsupportedResource
}

@available(iOS 26.1, *)
/// Determines the retry cadence applied when a transport throws while processing a `PHAssetResourceUploadJob`.
public struct BackgroundUploadRetryPolicy: Sendable {
    public enum Strategy: Sendable {
        case none
        case exponential(initial: TimeInterval, multiplier: Double, maximum: TimeInterval)
        case custom(@Sendable (Int) -> TimeInterval?)
    }

    public var strategy: Strategy
    public init(strategy: Strategy = .none) {
        self.strategy = strategy
    }

    public static func exponentialBackoff(
        initial: TimeInterval = 5,
        multiplier: Double = 2,
        maximum: TimeInterval = 5 * 60
    ) -> Self {
        .init(strategy: .exponential(initial: initial, multiplier: multiplier, maximum: maximum))
    }

    func delay(for attempt: Int) -> TimeInterval? {
        guard attempt > 0 else { return 0 }
        switch strategy {
        case .none:
            return 0
        case let .exponential(initial, multiplier, maximum):
            let value = initial * pow(multiplier, Double(attempt - 1))
            return min(value, maximum)
        case let .custom(handler):
            return handler(attempt)
        }
    }
}

// MARK: - Logging

@available(iOS 26.1, *)
/// Lightweight logging surface that mirrors `os.Logger` without introducing additional dependencies.
public struct BackgroundUploadLogger: Sendable {
    public enum Level: Int, Sendable {
        case info
        case warning
        case error
    }

    public var onLog: @Sendable (Level, String) -> Void

    public init(onLog: @escaping @Sendable (Level, String) -> Void = { level, message in
        #if DEBUG
        print("[PhotoBackgroundUploadKit][\(level)] \(message)")
        #endif
    }) {
        self.onLog = onLog
    }

    func log(_ level: Level, _ message: String) {
        onLog(level, message)
    }
}

// MARK: - Job Descriptor

// MARK: - Descriptors & Context

@available(iOS 26.1, *)
/// Snapshot of a `PHAssetResourceUploadJob` created by the host app. Useful for persisting metadata before the extension runs.
public struct BackgroundUploadJobDescriptor: Sendable {
    public let localIdentifier: String
    public let assetIdentifier: String
    public let requestedResourceTypes: [PHAssetResourceType]
    public let userInfo: [String: AnySendable]

    public init(
        localIdentifier: String,
        assetIdentifier: String,
        requestedResourceTypes: [PHAssetResourceType],
        userInfo: [String: AnySendable]
    ) {
        self.localIdentifier = localIdentifier
        self.assetIdentifier = assetIdentifier
        self.requestedResourceTypes = requestedResourceTypes
        self.userInfo = userInfo
    }
}

@available(iOS 26.1, *)
/// Wraps a `PHAssetResourceUploadJob` with incremental retry metadata passed into `BackgroundUploadTransport` implementations.
public struct BackgroundUploadJobContext: Sendable {
    public let job: PHAssetResourceUploadJob
    public let attempt: Int

    public init(job: PHAssetResourceUploadJob, attempt: Int) {
        self.job = job
        self.attempt = attempt
    }
}

@available(iOS 26.1, *)
/// Represents a single resource extracted from the Photos library for upload.
/// Designed to map onto `PHAssetResource` while remaining lightweight for testing.
public struct BackgroundUploadResourceContext: Sendable {
    public let jobIdentifier: String
    public let assetIdentifier: String
    public let resourceType: PHAssetResourceType?
    public let filename: String?
    public let dataProvider: @Sendable () async throws -> Data

    public init(
        jobIdentifier: String,
        assetIdentifier: String,
        resourceType: PHAssetResourceType?,
        filename: String?,
        dataProvider: @escaping @Sendable () async throws -> Data
    ) {
        self.jobIdentifier = jobIdentifier
        self.assetIdentifier = assetIdentifier
        self.resourceType = resourceType
        self.filename = filename
        self.dataProvider = dataProvider
    }
}

// MARK: - Protocols

@available(iOS 26.1, *)
/// Sends photo/video data to your backend based on a `PHAssetResourceUploadJob` received in the extension process.
public protocol BackgroundUploadTransport: Sendable {
    func upload(
        job: BackgroundUploadJobContext,
        resource: BackgroundUploadResourceContext,
        configuration: BackgroundUploadConfiguration
    ) async throws -> BackgroundUploadResponse
}

@available(iOS 26.1, *)
public struct BackgroundUploadResponse: Sendable {
    public enum Outcome: Sendable {
        case completed(URLResponse?)
        case retry(after: TimeInterval)
    }

    public let outcome: Outcome
    public let metadata: [String: AnySendable]

    public init(outcome: Outcome, metadata: [String: AnySendable] = [:]) {
        self.outcome = outcome
        self.metadata = metadata
    }
}

@available(iOS 26.1, *)
public struct BackgroundUploadJobState: Sendable {
    public enum Status: Sendable {
        case pending
        case inProgress(attempts: Int)
        case completed
        case failed(AnySendable)
    }

    public let jobIdentifier: String
    public let status: Status
    public let lastUpdated: Date

    public init(jobIdentifier: String, status: Status, lastUpdated: Date = Date()) {
        self.jobIdentifier = jobIdentifier
        self.status = status
        self.lastUpdated = lastUpdated
    }
}

@available(iOS 26.1, *)
/// Persists progress for background jobs so retry policies can be evaluated across extension invocations.
public protocol BackgroundUploadJobStore: Sendable {
    func loadState(for jobIdentifier: String) async -> BackgroundUploadJobState?
    func record(_ state: BackgroundUploadJobState) async
    func reset(jobIdentifier: String) async
}

@available(iOS 26.1, *)
/// High-level orchestrator called by `PHBackgroundResourceUploadExtension.process(_:)`.
public protocol BackgroundUploader: Sendable {
    func process(job: PHAssetResourceUploadJob, configuration: BackgroundUploadConfiguration) async -> PHBackgroundResourceUploadProcessingResult
}

@available(iOS 26.1, *)
/// Extracts `PHAssetResource` data for the given job. Default implementation relies on `PHAssetResourceManager`.
public protocol BackgroundUploadResourceProvider: Sendable {
    func resources(for job: PHAssetResourceUploadJob, configuration: BackgroundUploadConfiguration) async throws -> [BackgroundUploadResourceContext]
}

@available(iOS 26.1, *)
/// Groups the components required to execute a background upload pipeline.
public struct BackgroundUploadPipeline: Sendable {
    public let logger: BackgroundUploadLogger
    public let transport: any BackgroundUploadTransport
    public let jobStore: any BackgroundUploadJobStore
    public let resourceProvider: any BackgroundUploadResourceProvider
    public let uploader: any BackgroundUploader

    public init(
        logger: BackgroundUploadLogger,
        transport: any BackgroundUploadTransport,
        jobStore: any BackgroundUploadJobStore,
        resourceProvider: any BackgroundUploadResourceProvider,
        uploader: any BackgroundUploader
    ) {
        self.logger = logger
        self.transport = transport
        self.jobStore = jobStore
        self.resourceProvider = resourceProvider
        self.uploader = uploader
    }
}

@available(iOS 26.1, *)
/// Factory protocol that allows developers to inject custom dependencies for every upload pipeline.
public protocol BackgroundUploadPipelineFactory: Sendable {
    func makePipeline(configuration: BackgroundUploadConfiguration) -> BackgroundUploadPipeline
}

#endif
