import AVFoundation
import Foundation

final class FairPlayResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let configuration: DRMConfiguration
    private let client: SeasonsClient
    private let lock = NSLock()
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(configuration: DRMConfiguration, client: SeasonsClient) {
        self.configuration = configuration
        self.client = client
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard loadingRequest.request.url?.scheme?.lowercased() == "skd" else { return false }

        let identifier = ObjectIdentifier(loadingRequest)
        let task = Task { [weak self, weak loadingRequest] in
            guard let self, let loadingRequest else { return }
            do {
                try await self.fulfill(loadingRequest)
            } catch {
                #if DEBUG
                let diagnostic = error as NSError
                print("FairPlay key request failed [\(diagnostic.domain) \(diagnostic.code)]")
                #endif
                loadingRequest.finishLoading(with: error)
            }
            self.removeTask(identifier)
        }
        lock.withLock { tasks[identifier] = task }
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let identifier = ObjectIdentifier(loadingRequest)
        lock.withLock { tasks.removeValue(forKey: identifier) }?.cancel()
    }

    private func fulfill(_ loadingRequest: AVAssetResourceLoadingRequest) async throws {
        guard let skdURL = loadingRequest.request.url else {
            throw SeasonsError.fairPlayUnavailable
        }

        var certificateRequest = URLRequest(url: configuration.certificateURL)
        configuration.headers.forEach { certificateRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        let certificate = try await client.authenticatedData(for: certificateRequest)

        let contentIdentifier = Data(
            configuration.contentIdentifierStrategy.identifier(for: skdURL).utf8
        )
        let spcData = try loadingRequest.streamingContentKeyRequestData(
            forApp: certificate,
            contentIdentifier: contentIdentifier,
            options: nil
        )

        let licenseURL: URL
        if let configuredLicenseURL = configuration.licenseURL {
            licenseURL = configuredLicenseURL
        } else {
            let httpsLicense = skdURL.absoluteString.replacingOccurrences(of: "skd://", with: "https://")
            let licenseString = (configuration.licenseProxyPrefix ?? "") + httpsLicense
            guard let derivedLicenseURL = URL(string: licenseString) else {
                throw SeasonsError.fairPlayUnavailable
            }
            licenseURL = derivedLicenseURL
        }

        var licenseRequest = URLRequest(url: licenseURL)
        licenseRequest.httpMethod = "POST"
        licenseRequest.httpBody = spcData
        licenseRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        configuration.headers.forEach { licenseRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        let ckcData = try await client.authenticatedData(for: licenseRequest)

        loadingRequest.dataRequest?.respond(with: ckcData)
        loadingRequest.finishLoading()
    }

    private func removeTask(_ identifier: ObjectIdentifier) {
        lock.withLock { tasks.removeValue(forKey: identifier) }
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
