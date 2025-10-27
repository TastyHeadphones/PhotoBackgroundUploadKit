# PhotoBackgroundUploadKit

> Swift Package that wraps the upcoming PhotoKit background upload APIs (iOS 26.1) with modern Swift concurrency, testability, and extensibility.

[日本語はこちら](README.ja.md)

### Highlights
- Async/await-first orchestration for `PHBackgroundResourceUploadExtension`.
- Protocol-centered design (`BackgroundUploadTransport`, `BackgroundUploadJobStore`, `BackgroundUploader`) with battle-ready defaults.
- Factory-driven dependency injection via `BackgroundUploadPipelineFactory` so you can wire custom transports, stores, or loggers per app.
- Host-side helpers for creating `PHAssetResourceUploadJobChangeRequest`s and synchronizing configuration with the upload extension.
- Sample host app and background upload extension targets showing end-to-end integration.
- Unit tests ready for automation.

### Requirements
- Xcode with the iOS 26.1 SDK (Swift 6 toolchain).
- iOS 26.1 or later deployment target.

> ⚠️ Until the iOS 26.1 SDK is publicly available, the package ships lightweight shims for the upcoming PhotoKit background upload types. Remove the `PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS` flag in `Package.swift` once the real SDK is in use.

### Installation (Swift Package Manager)
Add the package URL to **File ▸ Add Packages...** in Xcode or to your `Package.swift`:

```swift
.package(url: "https://github.com/TastyHeadphones/PhotoBackgroundUploadKit.git", from: "0.1.0")
```

Then add the library product to the targets that need it:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "PhotoBackgroundUploadKit", package: "PhotoBackgroundUploadKit")
    ]
)
```

### Quick Start

#### Host App
Configure a manager at launch, enqueue uploads when needed, and push custom metadata/resources via the change request callback:

```swift
let manager = PhotoBackgroundUploadManager(
    configuration: .init(
        extensionBundleIdentifier: "com.example.BackgroundUploadExtension",
        transportIdentifier: "com.example.transport",
        allowsCellularAccess: true,
        isUserInitiated: false
    )
)

Task.detached {
    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: ["ASSET-LOCAL-IDENTIFIER"], options: nil).firstObject else {
        return
    }

    try await manager.enqueueAssets([asset.localIdentifier]) { request in
        request.requestedResourceTypes = [.fullSizePhoto]
        request.userInfo["uploadToken"] = "your-app-token"
    }
}
```

The manager persists configuration and automatically publishes it to the extension through the shared bridge.

#### Extension
Subclass `PHBackgroundResourceUploadExtension` and forward to the built-in handler:

```swift
import PhotoBackgroundUploadKit

@main
final class BackgroundUploadExtension: PHBackgroundResourceUploadExtension {
    private lazy var handler = makeDefaultHandler()

    override func process(_ job: PHAssetResourceUploadJob) async -> PHBackgroundResourceUploadProcessingResult {
        await handler.process(job: job)
    }
}
```

The default handler uses `DefaultBackgroundUploader`, `URLSessionBackgroundUploadTransport`, and `InMemoryBackgroundUploadJobStore`. Override them by registering your own implementations through `PhotoBackgroundUploadManager`.

### Customization Points
1. **Pipeline Factory** – conform to `BackgroundUploadPipelineFactory` to inject bespoke transports, job stores, resource providers, loggers, or uploaders.
2. **Transport** – build your own `BackgroundUploadTransport` to talk to your backend (S3, CloudKit, etc.).
3. **Job Store** – implement `BackgroundUploadJobStore` for durable tracking (CoreData, SQLite, CloudKit).
4. **Resource Provider** – conform to `BackgroundUploadResourceProvider` when you want custom resource extraction logic.
5. **Uploader** – provide a bespoke `BackgroundUploader` to orchestrate multi-step pipelines.

Inject everything at once using a factory:

```swift
struct MyPipelineFactory: BackgroundUploadPipelineFactory {
    func makePipeline(configuration: BackgroundUploadConfiguration) -> BackgroundUploadPipeline {
        let logger = BackgroundUploadLogger()
        let transport = MyCustomTransport()
        let store = MyPersistentJobStore()
        let provider = PhotoKitBackgroundUploadResourceProvider()
        let uploader = DefaultBackgroundUploader(
            transport: transport,
            jobStore: store,
            resourceProvider: provider,
            logger: logger
        )
        return BackgroundUploadPipeline(
            logger: logger,
            transport: transport,
            jobStore: store,
            resourceProvider: provider,
            uploader: uploader
        )
    }
}

let manager = PhotoBackgroundUploadManager(
    configuration: config,
    pipelineFactory: MyPipelineFactory()
)

// Swap pipelines on the fly if needed
manager.updatePipelineFactory(MyPipelineFactory())
```

### Documentation
Public APIs include inline doc comments referencing the new PhotoKit types so Xcode Quick Help stays informative.

### Tests
- Run unit tests: `swift test`

### Samples
- Host App: `Examples/HostApp`
- Background Upload Extension: `Examples/BackgroundUploadExtension`

---

Made with ❤️ for future PhotoKit background uploads.
