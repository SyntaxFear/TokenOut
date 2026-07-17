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
    #expect(Pricing.cost(model: "claude-opus-4-5-20251101", usage: usage).usd == 5.0)
    #expect(Pricing.cost(model: "claude-opus-4-1", usage: usage).usd == 15.0)
    #expect(Pricing.cost(model: "claude-opus-4-8", usage: usage).usd == 5.0)
    #expect(Pricing.cost(model: "claude-fable-5", usage: usage).usd == 10.0)
    #expect(Pricing.cost(model: "claude-haiku-4-5-20251001", usage: usage).usd == 1.0)
}

@Test func cacheRatesApply() {
    let usage = TokenUsage(input: 0, output: 0, cacheWrite: 1_000_000,
                           cacheWrite1h: 1_000_000, cacheRead: 1_000_000)
    // Sonnet 4.6 (post-intro stable rate $3): 5m 1.25x + 1h 2x + read 0.1x = 3.75+6.00+0.30
    let cost = Pricing.cost(model: "claude-sonnet-4-6", usage: usage)
    #expect(abs(cost.usd - (3.75 + 6.00 + 0.30)) < 0.0001)
    // Sonnet 5 during intro window ($2 input): 2.50 + 4.00 + 0.20
    let intro = Pricing.cost(model: "claude-sonnet-5", usage: usage)
    #expect(abs(intro.usd - 6.70) < 0.0001)
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
