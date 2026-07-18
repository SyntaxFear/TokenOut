import Foundation
import TokenOutCore

enum MarketingPreviewData {
    static var snapshots: [UsageSnapshot] {
        let now = Date.now
        let calendar = Calendar(identifier: .gregorian)

        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset,
                          to: calendar.startOfDay(for: now)) ?? now
        }

        let claudeDaily = (0..<7).map { index in
            DayStat(
                day: day(index - 6),
                tokens: [2_980_000, 4_220_000, 3_740_000, 6_100_000, 4_860_000, 7_240_000, 5_125_330][index],
                costUSD: [10.42, 14.86, 12.31, 21.08, 16.74, 25.32, 18.33][index],
                costIsEstimated: true,
                byModel: ["claude-opus-4-8": 2_100_000, "claude-fable-5": 1_400_000]
            )
        }
        let codexDaily = (0..<7).map { index in
            DayStat(
                day: day(index - 6),
                tokens: [1_240_000, 2_010_000, 1_680_000, 2_920_000, 2_310_000, 3_480_000, 2_760_000][index],
                costUSD: [4.20, 6.82, 5.62, 9.94, 7.81, 11.76, 9.42][index],
                costIsEstimated: true,
                byModel: ["gpt-5.6-sol": 1_900_000]
            )
        }
        return [
            UsageSnapshot(
                providerID: .claude,
                fetchedAt: now,
                accountLabel: "Max",
                windows: [
                    LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.42,
                                resetsAt: now.addingTimeInterval(2.2 * 3600), duration: 5 * 3600),
                    LimitWindow(label: "Weekly", kind: .weekly, usedFraction: 0.67,
                                resetsAt: now.addingTimeInterval(3.4 * 86400), duration: 7 * 86400),
                ],
                tokens: TokenTotals(todayTokens: 5_125_330, weekTokens: 33_812_450,
                                    todayCostUSD: 18.33, weekCostUSD: 112.64,
                                    costIsEstimated: true),
                detail: [
                    DetailLine(title: "Projects", value: "4 active"),
                    DetailLine(title: "Latest session", value: "18 min ago"),
                ],
                daily: claudeDaily
            ),
            UsageSnapshot(
                providerID: .codex,
                fetchedAt: now,
                accountLabel: "Plus",
                windows: [
                    LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.28,
                                resetsAt: now.addingTimeInterval(3.6 * 3600), duration: 5 * 3600),
                    LimitWindow(label: "Weekly", kind: .weekly, usedFraction: 0.51,
                                resetsAt: now.addingTimeInterval(4.1 * 86400), duration: 7 * 86400),
                ],
                tokens: TokenTotals(todayTokens: 2_760_000, weekTokens: 17_440_000,
                                    todayCostUSD: 9.42, weekCostUSD: 58.31,
                                    costIsEstimated: true),
                detail: [
                    DetailLine(title: "Rollouts", value: "11 today"),
                    DetailLine(title: "Workspace", value: "3 projects"),
                ],
                breakdowns: [
                    Breakdown(title: "By workspace", rows: [
                        .init(name: "TokenOut", valueText: "1.6M", fraction: 0.58),
                        .init(name: "Website", valueText: "0.7M", fraction: 0.25),
                        .init(name: "Other", valueText: "0.5M", fraction: 0.17),
                    ]),
                ],
                daily: codexDaily
            ),
        ]
    }
}
