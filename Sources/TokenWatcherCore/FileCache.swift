import Foundation

public struct FileCacheEntry: Codable {
    public var byteOffset: Int
    public var entries: [UsageEntry]
    public var dedupIndex: [String: Int]

    public init(byteOffset: Int, entries: [UsageEntry], dedupIndex: [String: Int]) {
        self.byteOffset = byteOffset
        self.entries = entries
        self.dedupIndex = dedupIndex
    }
}

public actor FileCache {
    public static let shared = FileCache()

    private var store: [String: FileCacheEntry] = [:]
    private let cacheURL: URL

    private init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TokenWatcher", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        cacheURL = appSupport.appendingPathComponent("fileCache.json")
        if let data = try? Data(contentsOf: cacheURL),
           let loaded = try? JSONDecoder().decode([String: FileCacheEntry].self, from: data) {
            store = loaded
        }
    }

    public func entry(for url: URL) -> FileCacheEntry? {
        store[url.absoluteString]
    }

    public func set(_ entry: FileCacheEntry, for url: URL) {
        store[url.absoluteString] = entry
    }

    public func persist() {
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
