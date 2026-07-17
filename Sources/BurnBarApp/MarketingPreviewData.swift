import Foundation
import BurnBarCore

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
                costIsEstimated: true
            )
        }
        let codexDaily = (0..<7).map { index in
            DayStat(
                day: day(index - 6),
                tokens: [1_240_000, 2_010_000, 1_680_000, 2_920_000, 2_310_000, 3_480_000, 2_760_000][index],
                costUSD: [4.20, 6.82, 5.62, 9.94, 7.81, 11.76, 9.42][index],
                costIsEstimated: true
            )
        }
        let antigravityDaily = (0..<7).map { index in
            DayStat(
                day: day(index - 6),
                tokens: [310_000, 480_000, 260_000, 720_000, 550_000, 910_000, 803_000][index],
                costUSD: 0,
                costIsEstimated: true
            )
        }

        return [
            UsageSnapshot(
                providerID: .claude,
                fetchedAt: now,
                accountLabel: "Max",
                windows: [
                    LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.42,
                                resetsAt: now.addingTimeInterval(2.2 * 3600)),
                    LimitWindow(label: "Weekly", kind: .weekly, usedFraction: 0.67,
                                resetsAt: now.addingTimeInterval(3.4 * 86400)),
                ],
                tokens: TokenTotals(todayTokens: 5_125_330, weekTokens: 33_812_450,
                                    todayCostUSD: 18.33, weekCostUSD: 112.64,
                                    costIsEstimated: true),
                detail: [
                    DetailLine(title: "Projects", value: "4 active"),
                    DetailLine(title: "Latest session", value: "18 min ago"),
                ],
                breakdowns: [
                    Breakdown(title: "By project", rows: [
                        .init(name: "BurnBar", valueText: "2.8M", fraction: 0.55),
                        .init(name: "Client app", valueText: "1.5M", fraction: 0.29),
                        .init(name: "Research", valueText: "0.8M", fraction: 0.16),
                    ]),
                ],
                daily: claudeDaily
            ),
            UsageSnapshot(
                providerID: .codex,
                fetchedAt: now,
                accountLabel: "Plus",
                windows: [
                    LimitWindow(label: "5-hour", kind: .session, usedFraction: 0.28,
                                resetsAt: now.addingTimeInterval(3.6 * 3600)),
                    LimitWindow(label: "Weekly", kind: .weekly, usedFraction: 0.51,
                                resetsAt: now.addingTimeInterval(4.1 * 86400)),
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
                        .init(name: "BurnBar", valueText: "1.6M", fraction: 0.58),
                        .init(name: "Website", valueText: "0.7M", fraction: 0.25),
                        .init(name: "Other", valueText: "0.5M", fraction: 0.17),
                    ]),
                ],
                daily: codexDaily
            ),
            UsageSnapshot(
                providerID: .antigravity,
                fetchedAt: now,
                accountLabel: nil,
                windows: [],
                tokens: TokenTotals(todayTokens: 803_000, weekTokens: 4_033_000,
                                    costIsEstimated: true),
                detail: [
                    DetailLine(title: "Limits", value: "Not exposed locally by Antigravity"),
                    DetailLine(title: "Sessions today", value: "6"),
                    DetailLine(title: "Turns", value: "28 today · 164 this week"),
                    DetailLine(title: "Local source", value: "Conversation database"),
                ],
                breakdowns: [],
                daily: antigravityDaily
            ),
        ]
    }
}
