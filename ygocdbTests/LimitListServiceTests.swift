import Foundation
import Testing
@testable import ygocdb

@Suite(.serialized)
struct LimitListServiceTests {
    @Test func diskCacheIsImmediateAndRefreshUsesETagAfterInterval() async throws {
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let response = makeResponse()
        let data = try JSONEncoder().encode(response)
        let etag = "\"limits-v1\""
        let initialDate = Date(timeIntervalSince1970: 1_700_000_000)
        let session = makeMockSession()
        let apiURL = URL(string: "https://example.test/limits.json?show=all")!

        MockLimitListURLProtocol.reset(with: [
            .init(statusCode: 200, headers: ["ETag": etag], data: data)
        ])

        let initialService = LimitListService(
            apiURL: apiURL,
            session: session,
            cacheDirectory: cacheDirectory,
            refreshInterval: 24 * 60 * 60,
            now: { initialDate }
        )
        #expect(try await initialService.fetchLimitLists(forceRefresh: true) == response)
        #expect(MockLimitListURLProtocol.requests.count == 1)

        let freshService = LimitListService(
            apiURL: apiURL,
            session: session,
            cacheDirectory: cacheDirectory,
            refreshInterval: 24 * 60 * 60,
            now: { initialDate.addingTimeInterval(60 * 60) }
        )
        #expect(await freshService.cachedLimitLists() == response)
        #expect(try await freshService.fetchLimitLists() == response)
        #expect(MockLimitListURLProtocol.requests.count == 1)

        MockLimitListURLProtocol.append(
            .init(statusCode: 304, headers: ["ETag": etag], data: Data())
        )
        let staleService = LimitListService(
            apiURL: apiURL,
            session: session,
            cacheDirectory: cacheDirectory,
            refreshInterval: 24 * 60 * 60,
            now: { initialDate.addingTimeInterval(25 * 60 * 60) }
        )
        #expect(await staleService.cachedLimitLists() == response)
        #expect(try await staleService.fetchLimitLists() == response)
        #expect(MockLimitListURLProtocol.requests.count == 2)
        #expect(MockLimitListURLProtocol.requests.last?.value(forHTTPHeaderField: "If-None-Match") == etag)

        MockLimitListURLProtocol.append(
            .init(statusCode: 500, headers: [:], data: Data())
        )
        let offlineService = LimitListService(
            apiURL: apiURL,
            session: session,
            cacheDirectory: cacheDirectory,
            refreshInterval: 24 * 60 * 60,
            now: { initialDate.addingTimeInterval(50 * 60 * 60) }
        )
        #expect(try await offlineService.fetchLimitLists() == response)
        #expect(MockLimitListURLProtocol.requests.count == 3)

        let retryService = LimitListService(
            apiURL: apiURL,
            session: session,
            cacheDirectory: cacheDirectory,
            refreshInterval: 24 * 60 * 60,
            now: { initialDate.addingTimeInterval(51 * 60 * 60) }
        )
        #expect(try await retryService.fetchLimitLists() == response)
        #expect(MockLimitListURLProtocol.requests.count == 3)
    }

    @Test func concurrentFetchesShareOneRequest() async throws {
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let response = makeResponse()
        let data = try JSONEncoder().encode(response)
        MockLimitListURLProtocol.reset(with: [
            .init(statusCode: 200, headers: [:], data: data)
        ])

        let service = LimitListService(
            apiURL: URL(string: "https://example.test/limits.json?show=all")!,
            session: makeMockSession(),
            cacheDirectory: cacheDirectory
        )

        async let first = service.fetchLimitLists()
        async let second = service.fetchLimitLists()
        let results = try await [first, second]

        #expect(results == [response, response])
        #expect(MockLimitListURLProtocol.requests.count == 1)
    }

    private func temporaryCacheDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitListServiceTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockLimitListURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeResponse() -> LimitListResponse {
        let empty = LimitList(date: "2026-07-01", forbidden: [:], limited: [:], semiLimited: [:])
        return LimitListResponse(
            ja: LimitList(
                date: "2026-07-01",
                forbidden: ["4426": "デビル・フランケン"],
                limited: [:],
                semiLimited: [:]
            ),
            cn: empty,
            en: empty,
            old: LimitListHistory(
                ja: ["2026-04-01": LimitListSnapshot(forbidden: [:], limited: ["4426": "デビル・フランケン"], semiLimited: [:])],
                cn: [:],
                en: [:]
            )
        )
    }
}

private final class MockLimitListURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let headers: [String: String]
        let data: Data
    }

    private static let lock = NSLock()
    private static var stubs: [Stub] = []
    private(set) static var requests: [URLRequest] = []

    static func reset(with newStubs: [Stub]) {
        lock.lock()
        defer { lock.unlock() }
        stubs = newStubs
        requests = []
    }

    static func append(_ stub: Stub) {
        lock.lock()
        defer { lock.unlock() }
        stubs.append(stub)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub: Stub?
        Self.lock.lock()
        Self.requests.append(request)
        stub = Self.stubs.isEmpty ? nil : Self.stubs.removeFirst()
        Self.lock.unlock()

        guard let stub,
              let response = HTTPURLResponse(
                url: request.url!,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: stub.headers
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !stub.data.isEmpty {
            client?.urlProtocol(self, didLoad: stub.data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
