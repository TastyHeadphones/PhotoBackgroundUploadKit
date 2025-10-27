import Foundation
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)
@available(iOS 26.1, *)
@MainActor
/// Prepares `PHAssetResourceUploadJobChangeRequest` instances for each asset identifier.
final class BackgroundUploadScheduler {
    private let configuration: BackgroundUploadConfiguration
    private let logger: BackgroundUploadLogger

    init(configuration: BackgroundUploadConfiguration, logger: BackgroundUploadLogger) {
        self.configuration = configuration
        self.logger = logger
    }

    func enqueueAssets(
        _ assetIdentifiers: [String],
        userInfo: [String: AnySendable],
        customize: ((PHAssetResourceUploadJobChangeRequest) -> Void)?
    ) async throws -> [BackgroundUploadJobDescriptor] {
        logger.log(.info, "Preparing background upload jobs for \(assetIdentifiers.count) asset(s)")

        return assetIdentifiers.map { assetIdentifier in
            let request = PHAssetResourceUploadJobChangeRequest(assetLocalIdentifier: assetIdentifier)
            request.extensionBundleIdentifier = configuration.extensionBundleIdentifier
            request.preferredTransportIdentifier = configuration.transportIdentifier
            request.allowsCellularAccess = configuration.allowsCellularAccess
            request.isUserInitiated = configuration.isUserInitiated
            let mergedDefaults = configuration.defaultUserInfo.merging(userInfo) { _, new in new }
            request.userInfo = mergedDefaults.reduce(into: [AnyHashable: Any]()) { partial, element in
                partial[element.key] = element.value.value
            }
            request.requestedResourceTypes = discoverResourceTypes(for: assetIdentifier)
            customize?(request)
            logger.log(.info, "Prepared job for asset \(assetIdentifier)")
            let normalizedUserInfo = request.userInfo.reduce(into: [String: AnySendable]()) { partial, element in
                if let key = element.key as? String {
                    partial[key] = AnySendable(element.value)
                }
            }
            return BackgroundUploadJobDescriptor(
                localIdentifier: request.makeJobPlaceholder().localIdentifier,
                assetIdentifier: assetIdentifier,
                requestedResourceTypes: request.requestedResourceTypes,
                userInfo: normalizedUserInfo
            )
        }
    }

    private func discoverResourceTypes(for identifier: String) -> [PHAssetResourceType] {
        #if PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS
        return [.photo]
        #else
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            return []
        }
        let resources = PHAssetResource.assetResources(for: asset)
        return Array(Set(resources.map { $0.type }))
        #endif
    }
}
#endif
