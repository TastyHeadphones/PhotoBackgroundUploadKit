import Foundation
#if canImport(Photos)
import Photos
#endif

#if PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS

/// Shims that mimic the iOS 26.1 PhotoKit background upload API surface so the package can be compiled and tested with older SDKs.
/// Remove ``PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS`` once Apple ships the real types.

@available(iOS 26.1, *)
public enum PHBackgroundResourceUploadProcessingResult: Sendable {
    case finished
    case retry(after: TimeInterval)
    case failure(any Error)
}

@available(iOS 26.1, *)
open class PHBackgroundResourceUploadExtension: NSObject {
    open func process(_ job: PHAssetResourceUploadJob) async -> PHBackgroundResourceUploadProcessingResult {
        .finished
    }
}

@available(iOS 26.1, *)
public final class PHAssetResourceUploadJob: NSObject, @unchecked Sendable {
    public let localIdentifier: String
    public let assetLocalIdentifier: String
    public var userInfo: [AnyHashable: Any]?
    public var requestedResourceTypes: [PHAssetResourceType]

    public init(
        localIdentifier: String = UUID().uuidString,
        assetLocalIdentifier: String,
        userInfo: [AnyHashable: Any]? = nil,
        requestedResourceTypes: [PHAssetResourceType] = []
    ) {
        self.localIdentifier = localIdentifier
        self.assetLocalIdentifier = assetLocalIdentifier
        self.userInfo = userInfo
        self.requestedResourceTypes = requestedResourceTypes
    }
}

@available(iOS 26.1, *)
public final class PHAssetResourceUploadJobChangeRequest: NSObject {
    public let assetLocalIdentifier: String
    public var userInfo: [AnyHashable: Any] = [:]
    public var allowsCellularAccess: Bool = true
    public var isUserInitiated: Bool = false
    public var requestedResourceTypes: [PHAssetResourceType] = []
    public var preferredTransportIdentifier: String?
    public var extensionBundleIdentifier: String?

    public init(assetLocalIdentifier: String) {
        self.assetLocalIdentifier = assetLocalIdentifier
    }

    public func makeJobPlaceholder() -> PHAssetResourceUploadJob {
        PHAssetResourceUploadJob(
            assetLocalIdentifier: assetLocalIdentifier,
            userInfo: userInfo,
            requestedResourceTypes: requestedResourceTypes
        )
    }
}

#endif
