import Foundation

#if canImport(Photos)
@available(iOS 26.1, *)
/// Minimal HTTP transport that posts each resource payload to a configurable endpoint.
public struct URLSessionBackgroundUploadTransport: BackgroundUploadTransport {
    private let session: URLSession
    private let destinationURL: URL

    public init(
        session: URLSession = .shared,
        destinationURL: URL = URL(string: "https://example.com/upload")!
    ) {
        self.session = session
        self.destinationURL = destinationURL
    }

    public func upload(
        job: BackgroundUploadJobContext,
        resource: BackgroundUploadResourceContext,
        configuration: BackgroundUploadConfiguration
    ) async throws -> BackgroundUploadResponse {
        var request = URLRequest(url: destinationURL)
        request.httpMethod = "POST"
        request.setValue(configuration.transportIdentifier, forHTTPHeaderField: "X-Background-Transport")
        request.setValue(job.job.localIdentifier, forHTTPHeaderField: "X-Job-Identifier")
        if let filename = resource.filename {
            request.setValue(filename, forHTTPHeaderField: "X-Resource-Filename")
        }
        let body = try await resource.dataProvider()
        if #available(iOS 26.1, macOS 12.0, *) {
            let (data, response) = try await session.upload(for: request, from: body)
            let metadata: [String: AnySendable] = [
                "byteCount": AnySendable(body.count),
                "responseLength": AnySendable(data.count)
            ]
            return BackgroundUploadResponse(outcome: .completed(response), metadata: metadata)
        } else {
            throw BackgroundUploadError.unsupportedResource
        }
    }
}
#endif
