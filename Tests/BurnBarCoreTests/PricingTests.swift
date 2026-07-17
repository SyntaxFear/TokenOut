import Testing
import Foundation
@testable import BurnBarCore

@Test func sonnetCostComputes() {
    let usage = TokenUsage(input: 1_000_000, output: 100_000, cacheWrite: 0, cacheRead: 0)
    let cost = Pricing.cost(model: "claude-sonnet-5", usage: usage)
    #expect(abs(cost.usd - (3.0 + 1.5)) < 0.0001)
    #expect(cost.isEstimated == false)
}

@Test func datedModelIDsPrefixMatch() {
    let usage = TokenUsage(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0)
    #expect(Pricing.cost(model: "claude-opus-4-5-20251101", usage: usage).usd == 15.0)
    #expect(Pricing.cost(model: "claude-opus-4-8", usage: usage).usd == 5.0)
    #expect(Pricing.cost(model: "claude-fable-5", usage: usage).usd == 10.0)
    #expect(Pricing.cost(model: "claude-haiku-4-5-20251001", usage: usage).usd == 1.0)
}

@Test func cacheRatesApply() {
    let usage = TokenUsage(input: 0, output: 0, cacheWrite: 1_000_000,
                           cacheWrite1h: 1_000_000, cacheRead: 1_000_000)
    let cost = Pricing.cost(model: "claude-sonnet-5", usage: usage)
    // 5m write 1.25x + 1h write 2x + read 0.1x of $3 input = 3.75 + 6.00 + 0.30
    #expect(abs(cost.usd - (3.75 + 6.00 + 0.30)) < 0.0001)
}

@Test func unknownModelFallsBackEstimated() {
    let usage = TokenUsage(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0)
    let cost = Pricing.cost(model: "claude-hyperion-9", usage: usage)
    #expect(cost.usd == 3.0)
    #expect(cost.isEstimated == true)
}

@Test func syntheticModelIsFree() {
    let usage = TokenUsage(input: 500, output: 500, cacheWrite: 0, cacheRead: 0)
    let cost = Pricing.cost(model: "<synthetic>", usage: usage)
    #expect(cost.usd == 0)
}
