import Foundation

struct ModelPricing: Sendable {
    let inputPer1M: Double
    let outputPer1M: Double
    let cacheCreatePer1M: Double
    let cacheReadPer1M: Double

    func cost(input: Int, output: Int, cacheCreate: Int, cacheRead: Int) -> Double {
        let m = 1_000_000.0
        return Double(input) / m * inputPer1M
            + Double(output) / m * outputPer1M
            + Double(cacheCreate) / m * cacheCreatePer1M
            + Double(cacheRead) / m * cacheReadPer1M
    }
}

private let pricingTable: [String: ModelPricing] = [
    "claude-opus-4-7":      .init(inputPer1M: 15.0,  outputPer1M: 75.0,  cacheCreatePer1M: 18.75, cacheReadPer1M: 1.50),
    "claude-opus-4-5":      .init(inputPer1M: 15.0,  outputPer1M: 75.0,  cacheCreatePer1M: 18.75, cacheReadPer1M: 1.50),
    "claude-opus-4-0":      .init(inputPer1M: 15.0,  outputPer1M: 75.0,  cacheCreatePer1M: 18.75, cacheReadPer1M: 1.50),
    "claude-3-opus":        .init(inputPer1M: 15.0,  outputPer1M: 75.0,  cacheCreatePer1M: 18.75, cacheReadPer1M: 1.50),
    "claude-sonnet-4-6":    .init(inputPer1M: 3.0,   outputPer1M: 15.0,  cacheCreatePer1M: 3.75,  cacheReadPer1M: 0.30),
    "claude-sonnet-4-5":    .init(inputPer1M: 3.0,   outputPer1M: 15.0,  cacheCreatePer1M: 3.75,  cacheReadPer1M: 0.30),
    "claude-3-7-sonnet":    .init(inputPer1M: 3.0,   outputPer1M: 15.0,  cacheCreatePer1M: 3.75,  cacheReadPer1M: 0.30),
    "claude-3-5-sonnet":    .init(inputPer1M: 3.0,   outputPer1M: 15.0,  cacheCreatePer1M: 3.75,  cacheReadPer1M: 0.30),
    "claude-3-sonnet":      .init(inputPer1M: 3.0,   outputPer1M: 15.0,  cacheCreatePer1M: 3.75,  cacheReadPer1M: 0.30),
    "claude-haiku-4-5":     .init(inputPer1M: 0.80,  outputPer1M: 4.0,   cacheCreatePer1M: 1.00,  cacheReadPer1M: 0.08),
    "claude-3-5-haiku":     .init(inputPer1M: 0.80,  outputPer1M: 4.0,   cacheCreatePer1M: 1.00,  cacheReadPer1M: 0.08),
    "claude-3-haiku":       .init(inputPer1M: 0.25,  outputPer1M: 1.25,  cacheCreatePer1M: 0.30,  cacheReadPer1M: 0.03),
]

private let fallbackPricing = ModelPricing(inputPer1M: 3.0, outputPer1M: 15.0, cacheCreatePer1M: 3.75, cacheReadPer1M: 0.30)

func pricing(for model: String) -> ModelPricing {
    if let p = pricingTable[model] { return p }
    for (key, p) in pricingTable where model.contains(key) || model.hasPrefix(key) { return p }
    if model.contains("opus") { return pricingTable["claude-3-opus"]! }
    if model.contains("sonnet") { return pricingTable["claude-3-5-sonnet"]! }
    if model.contains("haiku") { return pricingTable["claude-3-haiku"]! }
    return fallbackPricing
}

extension Double {
    var formattedCost: String {
        if self < 0.01 { return String(format: "$%.4f", self) }
        if self < 1.0 { return String(format: "$%.3f", self) }
        return String(format: "$%.2f", self)
    }
}

extension Int {
    var formattedTokens: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
