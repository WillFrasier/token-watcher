import XCTest
@testable import TokenWatcherCore

final class PricingTests: XCTestCase {

    // MARK: - pricing(for:)

    func testExactModelMatch() {
        let p = pricing(for: "claude-sonnet-4-6")
        XCTAssertEqual(p.inputPer1M, 3.0)
        XCTAssertEqual(p.outputPer1M, 15.0)
    }

    func testExactOpusMatch() {
        let p = pricing(for: "claude-opus-4-7")
        XCTAssertEqual(p.inputPer1M, 15.0)
        XCTAssertEqual(p.outputPer1M, 75.0)
    }

    func testExactHaikuMatch() {
        let p = pricing(for: "claude-haiku-4-5")
        XCTAssertEqual(p.inputPer1M, 0.80)
        XCTAssertEqual(p.outputPer1M, 4.0)
    }

    func testContainsOpusFallback() {
        // A future model name not in the table but containing "opus"
        let p = pricing(for: "claude-opus-99-future")
        let expected = pricing(for: "claude-3-opus")
        XCTAssertEqual(p.inputPer1M, expected.inputPer1M)
        XCTAssertEqual(p.outputPer1M, expected.outputPer1M)
    }

    func testContainsSonnetFallback() {
        let p = pricing(for: "claude-sonnet-99-future")
        let expected = pricing(for: "claude-3-5-sonnet")
        XCTAssertEqual(p.inputPer1M, expected.inputPer1M)
        XCTAssertEqual(p.outputPer1M, expected.outputPer1M)
    }

    func testContainsHaikuFallback() {
        let p = pricing(for: "claude-haiku-99-future")
        let expected = pricing(for: "claude-3-haiku")
        XCTAssertEqual(p.inputPer1M, expected.inputPer1M)
        XCTAssertEqual(p.outputPer1M, expected.outputPer1M)
    }

    func testTotallyUnknownModelReturnsFallback() {
        let p = pricing(for: "gpt-4-turbo")
        // fallback is sonnet-tier pricing
        XCTAssertEqual(p.inputPer1M, 3.0)
        XCTAssertEqual(p.outputPer1M, 15.0)
    }

    // MARK: - ModelPricing.cost()

    func testCostCalculationExact() {
        let p = ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheCreatePer1M: 3.75, cacheReadPer1M: 0.30)
        // 1M input → $3, 1M output → $15
        let cost = p.cost(input: 1_000_000, output: 1_000_000, cacheCreate: 0, cacheRead: 0)
        XCTAssertEqual(cost, 18.0, accuracy: 1e-9)
    }

    func testCostCalculationWithCacheTokens() {
        let p = ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheCreatePer1M: 3.75, cacheReadPer1M: 0.30)
        // 1M cache create → $3.75, 1M cache read → $0.30
        let cost = p.cost(input: 0, output: 0, cacheCreate: 1_000_000, cacheRead: 1_000_000)
        XCTAssertEqual(cost, 4.05, accuracy: 1e-9)
    }

    func testCostZeroTokensIsZero() {
        let p = ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheCreatePer1M: 3.75, cacheReadPer1M: 0.30)
        XCTAssertEqual(p.cost(input: 0, output: 0, cacheCreate: 0, cacheRead: 0), 0.0)
    }

    func testCostSmallTokenCount() {
        let p = ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheCreatePer1M: 3.75, cacheReadPer1M: 0.30)
        // 1000 input tokens → $3 / 1000 = $0.003
        let cost = p.cost(input: 1_000, output: 0, cacheCreate: 0, cacheRead: 0)
        XCTAssertEqual(cost, 0.003, accuracy: 1e-9)
    }

    func testCostAllComponentsCombined() {
        let p = ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheCreatePer1M: 3.75, cacheReadPer1M: 0.30)
        let cost = p.cost(input: 500_000, output: 200_000, cacheCreate: 100_000, cacheRead: 50_000)
        let expected = 0.5 * 3.0 + 0.2 * 15.0 + 0.1 * 3.75 + 0.05 * 0.30
        XCTAssertEqual(cost, expected, accuracy: 1e-9)
    }

    // MARK: - Double.formattedCost

    func testFormattedCostBelowOneCent() {
        XCTAssertEqual(0.005.formattedCost, "$0.0050")
        XCTAssertEqual(0.0001.formattedCost, "$0.0001")
        XCTAssertEqual(0.0099.formattedCost, "$0.0099")
    }

    func testFormattedCostBelowOneDollar() {
        XCTAssertEqual(0.123.formattedCost, "$0.123")
        XCTAssertEqual(0.999.formattedCost, "$0.999")
        XCTAssertEqual(0.01.formattedCost, "$0.010")
    }

    func testFormattedCostOneOrMore() {
        XCTAssertEqual(1.0.formattedCost, "$1.00")
        XCTAssertEqual(12.345.formattedCost, "$12.35")
        XCTAssertEqual(100.0.formattedCost, "$100.00")
    }

    func testFormattedCostZero() {
        XCTAssertEqual(0.0.formattedCost, "$0.0000")
    }

    // MARK: - Int.formattedTokens

    func testFormattedTokensRaw() {
        XCTAssertEqual(0.formattedTokens, "0")
        XCTAssertEqual(500.formattedTokens, "500")
        XCTAssertEqual(999.formattedTokens, "999")
    }

    func testFormattedTokensKilo() {
        XCTAssertEqual(1_000.formattedTokens, "1.0K")
        XCTAssertEqual(1_500.formattedTokens, "1.5K")
        XCTAssertEqual(999_999.formattedTokens, "1000.0K")
    }

    func testFormattedTokensMega() {
        XCTAssertEqual(1_000_000.formattedTokens, "1.0M")
        XCTAssertEqual(2_500_000.formattedTokens, "2.5M")
        XCTAssertEqual(10_000_000.formattedTokens, "10.0M")
    }
}
