import Foundation
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)
@available(iOS 26.1, *)
/// Extracts PhotoKit resources (`PHAssetResource`) for a given job using `PHAssetResourceManager`.
/// Under the shim configuration the provider expects `ShimUploadResource` instances in `PHAssetResourceUploadJob.userInfo`.
public struct PhotoKitBackgroundUploadResourceProvider: BackgroundUploadResourceProvider {
    public init() {}

    public func resources(for job: PHAssetResourceUploadJob, configuration: BackgroundUploadConfiguration) async throws -> [BackgroundUploadResourceContext] {
        #if PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS
        guard
            let resources = job.userInfo?["resources"] as? [ShimUploadResource]
        else {
            throw BackgroundUploadError.resourcesMissing
        }
        return resources.map { resource in
            BackgroundUploadResourceContext(
                jobIdentifier: job.localIdentifier,
                assetIdentifier: job.assetLocalIdentifier,
                resourceType: resource.type,
                filename: resource.filename,
                dataProvider: { resource.data }
            )
        }
        #else
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [job.assetLocalIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw BackgroundUploadError.assetNotFound
        }
        let assetResources = PHAssetResource.assetResources(for: asset)
        let filteredResources: [PHAssetResource]
        if job.requestedResourceTypes.isEmpty {
            filteredResources = assetResources
        } else {
            filteredResources = assetResources.filter { job.requestedResourceTypes.contains($0.type) }
        }
        return try await withThrowingTaskGroup(of: BackgroundUploadResourceContext.self) { group in
            for resource in filteredResources {
                group.addTask {
                    let data = try await ResourceLoader.load(resource: resource)
                    return BackgroundUploadResourceContext(
                        jobIdentifier: job.localIdentifier,
                        assetIdentifier: asset.localIdentifier,
                        resourceType: resource.type,
                        filename: resource.originalFilename,
                        dataProvider: { data }
                    )
                }
            }
            return try await group.reduce(into: [BackgroundUploadResourceContext]()) { partial, item in
                partial.append(item)
            }
        }
        #endif
    }
}

#if PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS
@available(iOS 26.1, *)
/// Simple in-package container that emulates `PHAssetResource` during development until the real PhotoKit APIs ship.
public struct ShimUploadResource: Sendable {
    public let type: PHAssetResourceType
    public let filename: String?
    public let data: Data

    public init(type: PHAssetResourceType, filename: String?, data: Data) {
        self.type = type
        self.filename = filename
        self.data = data
    }
}
#endif

@available(iOS 26.1, *)
enum ResourceLoader {
    #if !PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS
    static func load(resource: PHAssetResource) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            var collected = Data()
            PHAssetResourceManager.default().requestData(for: resource, options: options) { chunk in
                collected.append(chunk)
            } completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: collected)
                }
            }
        }
    }
    #endif
}
#endif
