# PhotoBackgroundUploadKit

[English](README.md)

### ハイライト
- `PHBackgroundResourceUploadExtension` を対象とした async/await ベースのラッパー。
- `BackgroundUploadTransport`・`BackgroundUploadJobStore`・`BackgroundUploader` など、プロトコル中心の設計と既定実装。
- `BackgroundUploadPipelineFactory` を使ったファクトリーベースの依存性注入で、カスタム実装をまとめて差し替え可能。
- ホストアプリから `PHAssetResourceUploadJobChangeRequest` を構築し、拡張機能と設定を同期するヘルパー。
- サンプルホストアプリとバックグラウンドアップロード拡張ターゲットを同梱。
- ユニットテストを同梱し、自動化に備えています。

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

### ドキュメント
公開 API には PhotoKit の新しい型を参照したドキュメントコメントを付与しているため、Xcode の Quick Help からそのまま参照できます。

### テスト
- `swift test`

### サンプル
- ホストアプリ: `Examples/HostApp`
- アップロード拡張: `Examples/BackgroundUploadExtension`
