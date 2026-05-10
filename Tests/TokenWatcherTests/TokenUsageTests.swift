import XCTest
@testable import TokenWatcherCore

final class TokenUsageTests: XCTestCase {

    func testDefaultInitIsZero() {
        let u = TokenUsage()
        XCTAssertEqual(u.inputTokens, 0)
        XCTAssertEqual(u.outputTokens, 0)
        XCTAssertEqual(u.cacheCreationTokens, 0)
        XCTAssertEqual(u.cacheReadTokens, 0)
        XCTAssertEqual(u.costUSD, 0)
        XCTAssertEqual(u.totalTokens, 0)
    }

    func testTotalTokensSumsAllFields() {
        let u = TokenUsage(inputTokens: 100, outputTokens: 200, cacheCreationTokens: 50, cacheReadTokens: 25, costUSD: 1.0)
        XCTAssertEqual(u.totalTokens, 375)
    }

    func testTotalTokensIgnoresCost() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 999)
        let b = TokenUsage(inputTokens: 10, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 0)
        XCTAssertEqual(a.totalTokens, b.totalTokens)
    }

    func testAdditionOperatorSumsAllFields() {
        let a = TokenUsage(inputTokens: 10, outputTokens: 20, cacheCreationTokens: 5, cacheReadTokens: 3, costUSD: 0.5)
        let b = TokenUsage(inputTokens: 1,  outputTokens: 2,  cacheCreationTokens: 0, cacheReadTokens: 1, costUSD: 0.1)
        let result = a + b
        XCTAssertEqual(result.inputTokens, 11)
        XCTAssertEqual(result.outputTokens, 22)
        XCTAssertEqual(result.cacheCreationTokens, 5)
        XCTAssertEqual(result.cacheReadTokens, 4)
        XCTAssertEqual(result.costUSD, 0.6, accuracy: 1e-9)
    }

    func testCompoundAssignmentMutatesInPlace() {
        var u = TokenUsage(inputTokens: 100, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 1.0)
        u += TokenUsage(inputTokens: 50, outputTokens: 25, cacheCreationTokens: 10, cacheReadTokens: 5, costUSD: 0.25)
        XCTAssertEqual(u.inputTokens, 150)
        XCTAssertEqual(u.outputTokens, 25)
        XCTAssertEqual(u.cacheCreationTokens, 10)
        XCTAssertEqual(u.cacheReadTokens, 5)
        XCTAssertEqual(u.costUSD, 1.25, accuracy: 1e-9)
    }

    func testAdditionDoesNotMutateLhs() {
        let a = TokenUsage(inputTokens: 100, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 0)
        let b = TokenUsage(inputTokens: 50,  outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 0)
        _ = a + b
        XCTAssertEqual(a.inputTokens, 100)
    }

    func testEquatableEqualValues() {
        let a = TokenUsage(inputTokens: 1, outputTokens: 2, cacheCreationTokens: 3, cacheReadTokens: 4, costUSD: 5.0)
        let b = TokenUsage(inputTokens: 1, outputTokens: 2, cacheCreationTokens: 3, cacheReadTokens: 4, costUSD: 5.0)
        XCTAssertEqual(a, b)
    }

    func testEquatableDifferentValues() {
        let a = TokenUsage(inputTokens: 1, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 0)
        let b = TokenUsage(inputTokens: 2, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 0)
        XCTAssertNotEqual(a, b)
    }

    func testReduceAcrossMultipleEntries() {
        let entries = [
            TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 0.1),
            TokenUsage(inputTokens: 20, outputTokens: 8, cacheCreationTokens: 2, cacheReadTokens: 1, costUSD: 0.2),
            TokenUsage(inputTokens: 5,  outputTokens: 3, cacheCreationTokens: 0, cacheReadTokens: 0, costUSD: 0.05),
        ]
        let total = entries.reduce(TokenUsage()) { $0 + $1 }
        XCTAssertEqual(total.inputTokens, 35)
        XCTAssertEqual(total.outputTokens, 16)
        XCTAssertEqual(total.cacheCreationTokens, 2)
        XCTAssertEqual(total.cacheReadTokens, 1)
        XCTAssertEqual(total.costUSD, 0.35, accuracy: 1e-9)
        XCTAssertEqual(total.totalTokens, 54)
    }
}
