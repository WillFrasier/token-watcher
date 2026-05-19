import XCTest
@testable import TokenWatcherCore

final class FileCacheTests: XCTestCase {
    var tmpDir: URL!
    var cacheURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        cacheURL = tmpDir.appendingPathComponent("test-cache.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
        try await super.tearDown()
    }

    // MARK: - Incremental append

    func testIncrementalAppendOnlyParsesNewLines() async throws {
        let fileURL = tmpDir.appendingPathComponent("session.jsonl")
        let cache = FileCache(cacheURL: cacheURL)

        try makeLine(msgId: "m1", reqId: "r1", input: 100).write(to: fileURL, atomically: true, encoding: .utf8)
        let first = await UsageParser.loadFile(at: fileURL, cache: cache)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].inputTokens, 100)

        append(line: makeLine(msgId: "m2", reqId: "r2", input: 200), to: fileURL)

        let second = await UsageParser.loadFile(at: fileURL, cache: cache)
        XCTAssertEqual(second.count, 2)
        guard second.count >= 2 else { return }
        XCTAssertEqual(second[1].inputTokens, 200)

        // Verify cached offset advanced to end of file
        let entry = await cache.entry(for: fileURL)
        let fileSize = ((try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.size] as? Int) ?? 0
        XCTAssertEqual(entry?.byteOffset, fileSize)
    }

    // MARK: - Cache hit

    func testCacheHitReturnsStoredEntriesWithoutRereading() async throws {
        let fileURL = tmpDir.appendingPathComponent("session.jsonl")
        let cache = FileCache(cacheURL: cacheURL)

        try makeLine(msgId: "m1", reqId: "r1", input: 77).write(to: fileURL, atomically: true, encoding: .utf8)
        let first = await UsageParser.loadFile(at: fileURL, cache: cache)
        XCTAssertEqual(first.count, 1)

        // File unchanged — second load must return same result
        let second = await UsageParser.loadFile(at: fileURL, cache: cache)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second[0].inputTokens, 77)
    }

    // MARK: - Truncation / replacement detection

    func testTruncatedFileTriggersFullReparse() async throws {
        let fileURL = tmpDir.appendingPathComponent("session.jsonl")
        let cache = FileCache(cacheURL: cacheURL)

        // Write two lines so byteOffset ends up large
        let twoLines = makeLine(msgId: "m1", reqId: "r1", input: 10) + "\n"
                     + makeLine(msgId: "m2", reqId: "r2", input: 20)
        try twoLines.write(to: fileURL, atomically: true, encoding: .utf8)
        let _ = await UsageParser.loadFile(at: fileURL, cache: cache)

        // Replace with a shorter file containing a different entry
        try makeLine(msgId: "m3", reqId: "r3", input: 999)
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let entries = await UsageParser.loadFile(at: fileURL, cache: cache)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].inputTokens, 999, "Truncation must trigger full re-parse, not return stale cache")
    }

    // MARK: - Cross-boundary streaming dedup

    func testStreamingDedupAcrossIncrementalReads() async throws {
        let fileURL = tmpDir.appendingPathComponent("session.jsonl")
        let cache = FileCache(cacheURL: cacheURL)

        // First FSEvent: partial streaming snapshot (50 input tokens)
        try makeLine(msgId: "stream-msg", reqId: "req1", input: 50, output: 100)
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let first = await UsageParser.loadFile(at: fileURL, cache: cache)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].inputTokens, 50)

        // Second FSEvent: Claude finishes streaming — final token count appended to same file
        append(line: makeLine(msgId: "stream-msg", reqId: "req1", input: 150, output: 300), to: fileURL)

        let second = await UsageParser.loadFile(at: fileURL, cache: cache)
        XCTAssertEqual(second.count, 1, "Same dedupKey must overwrite, not create duplicate entry")
        XCTAssertEqual(second[0].inputTokens, 150, "Final token count must win")
        XCTAssertEqual(second[0].outputTokens, 300)
    }

    // MARK: - Multiple files in project

    func testParseProjectAggregatesAllFilesInDir() async throws {
        let cache = FileCache(cacheURL: cacheURL)

        for i in 1...3 {
            let f = tmpDir.appendingPathComponent("session-\(i).jsonl")
            try makeLine(msgId: "m\(i)", reqId: "r\(i)", input: i * 10)
                .write(to: f, atomically: true, encoding: .utf8)
        }

        let entries = await UsageParser.parseProject(at: tmpDir, cache: cache)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.inputTokens).sorted(), [10, 20, 30])
    }

    // MARK: - Disk persistence roundtrip

    func testPersistAndReloadAcrossInstances() async throws {
        let fileURL = tmpDir.appendingPathComponent("session.jsonl")
        let cache1 = FileCache(cacheURL: cacheURL)

        try makeLine(msgId: "m1", reqId: "r1", input: 42)
            .write(to: fileURL, atomically: true, encoding: .utf8)
        let _ = await UsageParser.loadFile(at: fileURL, cache: cache1)
        await cache1.persist()

        // New instance loads from same cacheURL
        let cache2 = FileCache(cacheURL: cacheURL)
        let entry = await cache2.entry(for: fileURL)

        XCTAssertNotNil(entry, "Cache entry must survive persist + reload")
        XCTAssertEqual(entry?.entries.count, 1)
        XCTAssertEqual(entry?.entries[0].inputTokens, 42)
    }

    // MARK: - Helpers

    private func makeLine(
        msgId: String = "msg1", reqId: String = "req1",
        input: Int = 100, output: Int = 50
    ) -> String {
        let root: [String: Any] = [
            "type": "assistant",
            "timestamp": "2024-06-01T12:00:00.000Z",
            "sessionId": "sess1",
            "requestId": reqId,
            "isSidechain": false,
            "message": [
                "id": msgId,
                "model": "claude-sonnet-4-6",
                "usage": [
                    "input_tokens": input,
                    "output_tokens": output,
                    "cache_creation_input_tokens": 0,
                    "cache_read_input_tokens": 0,
                ],
            ] as [String: Any],
        ]
        let data = try! JSONSerialization.data(withJSONObject: root)
        return String(data: data, encoding: .utf8)!
    }

    private func append(line: String, to url: URL) {
        guard let handle = try? FileHandle(forWritingTo: url) else {
            XCTFail("Could not open \(url.lastPathComponent) for appending")
            return
        }
        handle.seekToEndOfFile()
        handle.write(("\n" + line).data(using: .utf8)!)
        try? handle.close()
    }
}
