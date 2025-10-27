#if canImport(SwiftUI) && os(iOS)
import SwiftUI
import Photos
import PhotoBackgroundUploadKit

@available(iOS 26.1, *)
@main
struct PhotoBackgroundUploadSampleApp: App {
    private let manager = PhotoBackgroundUploadManager(
        configuration: .init(
            extensionBundleIdentifier: "com.example.PhotoBackgroundUploadExtension",
            transportIdentifier: "default.transport",
            allowsCellularAccess: true,
            isUserInitiated: false
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
        }
    }
}

@available(iOS 26.1, *)
struct ContentView: View {
    @State private var statusMessage: String = "Idle"
    let manager: PhotoBackgroundUploadManager

    var body: some View {
        VStack(spacing: 24) {
            Text("Photo Background Upload Kit")
                .font(.title2.bold())
            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Simulate Enqueue") {
                Task {
                    do {
                        let jobs = try await manager.enqueueAssets(["ASSET-LOCAL-IDENTIFIER"]) { request in
                            request.requestedResourceTypes = [.fullSizePhoto]
#if PHOTO_BACKGROUND_UPLOAD_KIT_USE_SHIMS
                            request.userInfo["resources"] = [
                                ShimUploadResource(
                                    type: .photo,
                                    filename: "sample.jpg",
                                    data: Data("demo".utf8)
                                )
                            ]
#else
                            request.userInfo["uploadToken"] = "your-app-token"
#endif
                        }
                        statusMessage = "Scheduled \(jobs.count) job(s)"
                    } catch {
                        statusMessage = "Failed: \(error)"
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
#endif
