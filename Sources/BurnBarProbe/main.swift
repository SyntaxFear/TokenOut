// burnbar-probe — dev CLI that prints raw usage-endpoint responses so real
// fixtures can be captured and decoders verified against reality.
// Usage: burnbar-probe [claude|codex|all]   (default: all)

import Foundation
import BurnBarCore
import BurnBarProviders

let mode = CommandLine.arguments.dropFirst().first ?? "all"

func printJSON(_ data: Data) {
    if let object = try? JSONSerialization.jsonObject(with: data),
       let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
       let string = String(data: pretty, encoding: .utf8) {
        print(string)
    } else {
        print(String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>")
    }
}

func probeClaude() async {
    print("== Claude Code ==")
    guard var creds = ClaudeCredentials.load() else {
        print("no credentials found (keychain item or ~/.claude/.credentials.json)")
        return
    }
    print("credentials: found (plan: \(creds.subscriptionType ?? "?"), expired: \(creds.isExpired))")
    if creds.isExpired {
        if let refreshed = await ClaudeCredentials.refresh(creds) {
            print("refresh: ok")
            creds = refreshed
        } else {
            print("refresh: FAILED")
            return
        }
    }
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
    request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        print("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        printJSON(data)
        let windows = ClaudeUsageAPI.decodeWindows(from: data)
        print("decoded windows: \(windows.map { "\($0.label)=\(Format.pct($0.usedFraction))" }.joined(separator: ", "))")
    } catch {
        print("request failed: \(error)")
    }
}

func probeCodex() async {
    print("== Codex ==")
    guard var auth = CodexAuthReader.load() else {
        print("no credentials found (~/.codex/auth.json)")
        return
    }
    print("credentials: found (plan: \(auth.planType ?? "?"), account: \(auth.accountID != nil), expired: \(auth.isExpired))")
    if auth.isExpired {
        if let refreshed = await CodexAuthReader.refresh(auth) {
            print("refresh: ok")
            auth = refreshed
        } else {
            print("refresh: FAILED")
            return
        }
    }
    var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
    request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
    if let accountID = auth.accountID {
        request.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id")
    }
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        print("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        printJSON(data)
        let windows = CodexUsageAPI.decodeWindows(from: data)
        print("decoded windows: \(windows.map { "\($0.label)=\(Format.pct($0.usedFraction))" }.joined(separator: ", "))")
    } catch {
        print("request failed: \(error)")
    }
}

func probeTranscripts() async {
    print("== Claude transcripts ==")
    let entries = await ClaudeTranscriptScanner.shared.recentEntries()
    let now = Date.now
    let today = ClaudeTranscriptParser.total(
        entries: entries, in: Calendar.current.startOfDay(for: now)...now)
    let week = ClaudeTranscriptParser.total(
        entries: entries, in: now.addingTimeInterval(-7 * 86400)...now)
    print("entries (8d): \(entries.count)")
    print("today: \(Format.tokens(today.tokens.total)) tokens, \(Format.usd(today.costUSD))")
    print("week:  \(Format.tokens(week.tokens.total)) tokens, \(Format.usd(week.costUSD))")
}

func probeAntigravity() async {
    print("== Antigravity ==")
    let provider = AntigravityProvider()
    guard await provider.detectInstallation() else {
        print("not installed")
        return
    }
    do {
        let snapshot = try await provider.fetchUsage()
        for line in snapshot.detail { print("\(line.title): \(line.value)") }
        if let tokens = snapshot.tokens {
            print("est tokens today: \(Format.tokens(tokens.todayTokens)), week: \(Format.tokens(tokens.weekTokens))")
        }
    } catch {
        print("fetch failed: \(error)")
    }
}

await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
    Task {
        if mode == "claude" || mode == "all" {
            await probeClaude()
            await probeTranscripts()
        }
        if mode == "codex" || mode == "all" { await probeCodex() }
        if mode == "antigravity" || mode == "all" { await probeAntigravity() }
        done.resume()
    }
}
