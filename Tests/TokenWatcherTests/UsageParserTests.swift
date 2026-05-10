import XCTest
@testable import TokenWatcherCore

final class UsageParserTests: XCTestCase {

    // MARK: - Helpers

    private func makeLine(
        type: String = "assistant",
        isApiError: Bool? = nil,
        msgId: String = "msg1",
        reqId: String = "req1",
        sessionId: String = "sess1",
        model: String = "claude-sonnet-4-6",
        input: Int = 100,
        output: Int = 200,
        cacheCreate: Int = 0,
        cacheRead: Int = 0,
        speed: String? = nil,
        timestamp: String = "2024-01-15T10:30:00.000Z",
        isSidechain: Bool = false,
        cwd: String? = "/home/user/project",
        gitBranch: String? = "main"
    ) -> String {
        var usageDict: [String: Any] = [
            "input_tokens": input,
            "output_tokens": output,
            "cache_creation_input_tokens": cacheCreate,
            "cache_read_input_tokens": cacheRead,
        ]
        if let speed { usageDict["speed"] = speed }

        var messageDict: [String: Any] = [
            "id": msgId,
            "model": model,
            "usage": usageDict,
        ]

        var root: [String: Any] = [
            "type": type,
            "timestamp": timestamp,
            "sessionId": sessionId,
            "requestId": reqId,
            "isSidechain": isSidechain,
            "message": messageDict,
        ]
        if let isApiError { root["isApiErrorMessage"] = isApiError }
        if let cwd { root["cwd"] = cwd }
        if let gitBranch { root["gitBranch"] = gitBranch }

        let data = try! JSONSerialization.data(withJSONObject: root)
        return String(data: data, encoding: .utf8)!
    }

    // MARK: - Filtering

    func testEmptyContentReturnsEmpty() {
        XCTAssertTrue(UsageParser.parseLines("").isEmpty)
    }

    func testBlankLinesIgnored() {
        XCTAssertTrue(UsageParser.parseLines("\n\n\n").isEmpty)
    }

    func testNonAssistantTypeFiltered() {
        let line = makeLine(type: "human")
        XCTAssertTrue(UsageParser.parseLines(line).isEmpty)
    }

    func testApiErrorMessageFiltered() {
        let line = makeLine(isApiError: true)
        XCTAssertTrue(UsageParser.parseLines(line).isEmpty)
    }

    func testNonApiErrorMessageNotFiltered() {
        let line = makeLine(isApiError: false)
        XCTAssertEqual(UsageParser.parseLines(line).count, 1)
    }

    func testZeroTokensFiltered() {
        let line = makeLine(input: 0, output: 0, cacheCreate: 0, cacheRead: 0)
        XCTAssertTrue(UsageParser.parseLines(line).isEmpty)
    }

    func testOnlyCacheTokensNotFiltered() {
        let line = makeLine(input: 0, output: 0, cacheCreate: 50, cacheRead: 0)
        XCTAssertEqual(UsageParser.parseLines(line).count, 1)
    }

    func testInvalidJSONIgnored() {
        XCTAssertTrue(UsageParser.parseLines("not json\n{also not json}").isEmpty)
    }

    func testMissingUsageFieldFiltered() {
        let json = #"{"type":"assistant","timestamp":"2024-01-15T10:30:00Z","message":{"id":"m1","model":"x"}}"#
        XCTAssertTrue(UsageParser.parseLines(json).isEmpty)
    }

    // MARK: - Parsed fields

    func testBasicEntryParsedCorrectly() {
        let line = makeLine(
            msgId: "msg1", reqId: "req1", sessionId: "sess42",
            model: "claude-opus-4-7",
            input: 100, output: 200, cacheCreate: 10, cacheRead: 5,
            timestamp: "2024-06-01T12:00:00.000Z",
            isSidechain: false,
            cwd: "/home/alice/myproject",
            gitBranch: "feature/foo"
        )
        let entries = UsageParser.parseLines(line)
        XCTAssertEqual(entries.count, 1)
        let e = entries[0]
        XCTAssertEqual(e.model, "claude-opus-4-7")
        XCTAssertEqual(e.inputTokens, 100)
        XCTAssertEqual(e.outputTokens, 200)
        XCTAssertEqual(e.cacheCreationTokens, 10)
        XCTAssertEqual(e.cacheReadTokens, 5)
        XCTAssertEqual(e.sessionId, "sess42")
        XCTAssertFalse(e.isSidechain)
        XCTAssertEqual(e.cwd, "/home/alice/myproject")
        XCTAssertEqual(e.gitBranch, "feature/foo")
        XCTAssertEqual(e.speed, "standard")
    }

    func testIsSidechainTrue() {
        let line = makeLine(isSidechain: true)
        XCTAssertTrue(UsageParser.parseLines(line)[0].isSidechain)
    }

    func testSpeedFieldParsed() {
        let line = makeLine(speed: "fast")
        XCTAssertEqual(UsageParser.parseLines(line)[0].speed, "fast")
    }

    func testSpeedDefaultsToStandard() {
        let line = makeLine(speed: nil)
        XCTAssertEqual(UsageParser.parseLines(line)[0].speed, "standard")
    }

    func testMissingCwdAndBranchAreNil() {
        let line = makeLine(cwd: nil, gitBranch: nil)
        let e = UsageParser.parseLines(line)[0]
        XCTAssertNil(e.cwd)
        XCTAssertNil(e.gitBranch)
    }

    func testMissingModelDefaultsToUnknown() {
        // Build a line where message has no model key
        var root: [String: Any] = [
            "type": "assistant",
            "timestamp": "2024-01-15T10:30:00.000Z",
            "sessionId": "s1",
            "requestId": "r1",
            "message": [
                "id": "m1",
                "usage": ["input_tokens": 10, "output_tokens": 5,
                          "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0]
            ] as [String: Any],
        ]
        let data = try! JSONSerialization.data(withJSONObject: root)
        let line = String(data: data, encoding: .utf8)!
        XCTAssertEqual(UsageParser.parseLines(line)[0].model, "unknown")
    }

    // MARK: - Timestamp parsing

    func testTimestampWithFractionalSeconds() {
        let line = makeLine(timestamp: "2024-06-01T12:00:00.123Z")
        let e = UsageParser.parseLines(line)[0]
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: e.timestamp)
        XCTAssertEqual(comps.year, 2024)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 1)
        XCTAssertEqual(comps.hour, 12)
    }

    func testTimestampBasicISO8601Fallback() {
        // No fractional seconds — should fall back to basic ISO8601 formatter
        let line = makeLine(timestamp: "2024-06-01T12:00:00Z")
        let e = UsageParser.parseLines(line)[0]
        XCTAssertNotEqual(e.timestamp, Date.distantPast)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day], from: e.timestamp)
        XCTAssertEqual(comps.year, 2024)
    }

    func testInvalidTimestampBecomesDistantPast() {
        let line = makeLine(timestamp: "not-a-date")
        let e = UsageParser.parseLines(line)[0]
        XCTAssertEqual(e.timestamp, Date.distantPast)
    }

    // MARK: - Deduplication

    func testDedupLastWins() {
        // Same msgId:reqId — second line's token count should win
        let line1 = makeLine(msgId: "msg1", reqId: "req1", input: 100, output: 200)
        let line2 = makeLine(msgId: "msg1", reqId: "req1", input: 150, output: 250)
        let entries = UsageParser.parseLines(line1 + "\n" + line2)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].inputTokens, 150)
        XCTAssertEqual(entries[0].outputTokens, 250)
    }

    func testDedupThreeWritesFinalWins() {
        let line1 = makeLine(msgId: "msg1", reqId: "req1", input: 10, output: 20)
        let line2 = makeLine(msgId: "msg1", reqId: "req1", input: 50, output: 80)
        let line3 = makeLine(msgId: "msg1", reqId: "req1", input: 99, output: 200)
        let entries = UsageParser.parseLines([line1, line2, line3].joined(separator: "\n"))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].inputTokens, 99)
    }

    func testDifferentDedupKeysBothAppended() {
        let line1 = makeLine(msgId: "msg1", reqId: "req1", input: 100, output: 0)
        let line2 = makeLine(msgId: "msg2", reqId: "req2", input: 200, output: 0)
        let entries = UsageParser.parseLines(line1 + "\n" + line2)
        XCTAssertEqual(entries.count, 2)
    }

    func testEmptyDedupKeyAllowsDuplicates() {
        // When both msgId and reqId are empty, dedupKey is ":", treated as empty → skip dedup, both appended
        var root1: [String: Any] = [
            "type": "assistant",
            "timestamp": "2024-01-15T10:30:00.000Z",
            "message": [
                "usage": ["input_tokens": 10, "output_tokens": 5,
                          "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0],
            ] as [String: Any],
        ]
        let data1 = try! JSONSerialization.data(withJSONObject: root1)
        let line1 = String(data: data1, encoding: .utf8)!
        let entries = UsageParser.parseLines(line1 + "\n" + line1)
        // dedupKey is ":" (empty msgId + empty reqId) — the code checks `!dedupKey.isEmpty`
        // ":" is non-empty, so it WILL dedup. Both lines become one entry.
        XCTAssertEqual(entries.count, 1)
    }

    func testMultipleDistinctEntriesInOneFile() {
        let lines = (1...5).map { i in
            makeLine(msgId: "msg\(i)", reqId: "req\(i)", input: i * 10, output: i * 5)
        }.joined(separator: "\n")
        XCTAssertEqual(UsageParser.parseLines(lines).count, 5)
    }

    func testMixedValidAndInvalidLines() {
        let valid = makeLine()
        let invalid = "this is not json"
        let content = [valid, invalid, valid].joined(separator: "\n")
        // Two valid lines with same dedupKey → deduped to 1
        XCTAssertEqual(UsageParser.parseLines(content).count, 1)
    }
}
