# PhotoBackgroundUploadKit

> Swift Package that wraps the upcoming PhotoKit background upload APIs (iOS 26.1) with modern Swift concurrency, testability, and extensibility.

## English

### Highlights
- Async/await-first orchestration for `PHBackgroundResourceUploadExtension`.
- Protocol-centered design (`BackgroundUploadTransport`, `BackgroundUploadJobStore`, `BackgroundUploader`) with battle-ready defaults.
- Factory-driven dependency injection via `BackgroundUploadPipelineFactory` so you can wire custom transports, stores, or loggers per app.
- Host-side helpers for creating `PHAssetResourceUploadJobChangeRequest`s and synchronizing configuration with the upload extension.
- Sample host app and background upload extension targets showing end-to-end integration.
- Unit tests and GitHub Actions CI workflow ready for automation.

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

### Tests & CI
- Run unit tests: `swift test`
- GitHub Actions workflow: `.github/workflows/ci.yml`

### Samples
- Host App: `Examples/HostApp`
- Background Upload Extension: `Examples/BackgroundUploadExtension`

---

## 日本語

### ハイライト
- `PHBackgroundResourceUploadExtension` を対象とした async/await ベースのラッパー。
- `BackgroundUploadTransport`・`BackgroundUploadJobStore`・`BackgroundUploader` など、プロトコル中心の設計と既定実装。
- `BackgroundUploadPipelineFactory` を使ったファクトリーベースの依存性注入で、カスタム実装をまとめて差し替え可能。
- ホストアプリから `PHAssetResourceUploadJobChangeRequest` を構築し、拡張機能と設定を同期するヘルパー。
- サンプルホストアプリとバックグラウンドアップロード拡張ターゲットを同梱。
- ユニットテストと GitHub Actions ワークフローで自動化に対応。

### 必要環境
- iOS 26.1 SDK（Swift 6）に対応した Xcode。
- iOS 26.1 以降をターゲットとしたアプリ。

> ⚠️ iOS 26.1 SDK が一般公開されるまでは、PhotoKit の新しいバックグラウンドアップロード型を模擬するシムを同梱しています。実機 SDK に切り替えたら `Package.swift` の `PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS` フラグを削除してください。

### インストール (Swift Package Manager)
Xcode の **パッケージを追加** から URL を登録するか、`Package.swift` に次を追加します。

```swift
.package(url: "https://github.com/TastyHeadphones/PhotoBackgroundUploadKit.git", from: "0.1.0")
```

利用ターゲットにライブラリをリンクします。

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "PhotoBackgroundUploadKit", package: "PhotoBackgroundUploadKit")
    ]
)
```

### クイックスタート

#### ホストアプリ
起動時にマネージャーを初期化し、必要に応じてアップロードジョブを追加します。

```swift
let manager = PhotoBackgroundUploadManager(
    configuration: .init(
        extensionBundleIdentifier: "com.example.BackgroundUploadExtension",
        transportIdentifier: "com.example.transport"
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

#### 拡張機能
`PHBackgroundResourceUploadExtension` を継承し、ビルトインハンドラに委譲します。

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

### カスタマイズポイント
1. **Pipeline Factory** – `BackgroundUploadPipelineFactory` を実装してトランスポート・永続化・ロガーなどをまとめて注入。
2. **Transport** – `BackgroundUploadTransport` を実装して任意のバックエンドへ送信。
3. **JobStore** – `BackgroundUploadJobStore` を実装して永続化や再試行戦略を制御。
4. **ResourceProvider** – `BackgroundUploadResourceProvider` でリソース抽出のロジックを差し替え。
5. **Uploader** – `BackgroundUploader` そのものを差し替えて複雑なワークフローに対応。

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

manager.updatePipelineFactory(MyPipelineFactory())
```

### テストと CI
- `swift test` でユニットテストを実行できます。
- `.github/workflows/ci.yml` に GitHub Actions 用ワークフローを用意しています。

### サンプル
- ホストアプリ: `Examples/HostApp`
- アップロード拡張: `Examples/BackgroundUploadExtension`

---

Made with ❤️ for future PhotoKit background uploads.
