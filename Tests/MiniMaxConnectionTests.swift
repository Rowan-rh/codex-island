import Foundation

@main
struct MiniMaxConnectionTests {
    static var failures = 0

    static func expect(_ value: Bool, _ label: String) {
        if value { print("PASS \(label)") } else { failures += 1; print("FAIL \(label)") }
    }

    static func data(_ text: String) -> Data { Data(text.utf8) }

    static func main() async throws {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let full = data(#"{"plan_name":"Plus","model_remains":[{"model_name":"general","current_interval_remaining_percent":62.5,"current_weekly_remaining_percent":88,"current_weekly_status":1,"remains_time":9000000,"weekly_remains_time":345600000}]}"#)
        let parsed = try MiniMaxConnection.parse(full, now: now)
        expect(parsed.plan == "Plus", "reads the MiniMax plan name")
        expect(parsed.limits.map(\.id) == ["fiveHour", "weekly"], "reads the 5-hour and weekly windows")
        expect(abs((parsed.limits[0].usedFraction ?? 0) - 0.375) < 0.0001,
               "converts interval remaining percent to used percent")
        expect(abs((parsed.limits[1].usedFraction ?? 0) - 0.12) < 0.0001,
               "converts weekly remaining percent to used percent")
        expect(parsed.limits[0].resetAt == now.addingTimeInterval(9000),
               "converts interval reset duration from milliseconds")
        expect(parsed.limits[1].resetAt == now.addingTimeInterval(345600),
               "converts weekly reset duration from milliseconds")

        let unlimited = data(#"{"model_remains":[{"model_name":"general","current_interval_remaining_percent":100,"current_weekly_remaining_percent":100,"current_weekly_status":3}]}"#)
        let unlimitedUsage = try MiniMaxConnection.parse(unlimited, now: now)
        expect(unlimitedUsage.limits.map(\.id) == ["fiveHour"],
               "does not invent a weekly window for unlimited plans")
        expect(unlimitedUsage.limits[0].usedFraction == 0,
               "preserves a genuine zero percent reading")

        let countBased = data(#"{"model_remains":[{"model_name":"MiniMax-M2.7","current_interval_total_count":1500,"current_interval_usage_count":1497}]}"#)
        let countUsage = try MiniMaxConnection.parse(countBased, now: now)
        expect(abs((countUsage.primary?.usedFraction ?? 0) - 0.002) < 0.0001,
               "falls back to remaining-count semantics")

        do {
            _ = try MiniMaxConnection.parse(data(#"{"base_resp":{"status_code":1028,"status_msg":"quota exhausted"},"model_remains":[]}"#), now: now)
            expect(false, "rejects an API error response")
        } catch ProviderConnectionError.http(1028) {
            expect(true, "rejects an API error response")
        }
        do {
            _ = try MiniMaxConnection.parse(data(#"{"base_resp":{"status_code":1004,"status_msg":"login fail"}}"#), now: now)
            expect(false, "classifies an authentication response")
        } catch ProviderConnectionError.signIn {
            expect(true, "classifies an authentication response")
        }
        do {
            _ = try MiniMaxConnection.parse(data(#"{"model_remains":[{"model_name":"video","current_interval_remaining_percent":100}]}"#), now: now)
            expect(false, "ignores non-coding model quota rows")
        } catch {
            expect(true, "ignores non-coding model quota rows")
        }

        let plain = try MiniMaxConnection.credential(from: data(" sk-cn-test "))
        expect(plain.apiKey == "sk-cn-test", "reads a plain API key")
        let config = try MiniMaxConnection.credential(from: data(#"{"region":"cn","api_key":"sk-config-test"}"#))
        expect(config.apiKey == "sk-config-test", "reads the mmx config API key")
        let oauthConfig = try MiniMaxConnection.credential(from: data(#"{"region":"cn","oauth":{"access_token":"oauth-cn-test"}}"#))
        expect(oauthConfig.apiKey == "oauth-cn-test", "reads the mmx OAuth access token")
        do {
            _ = try MiniMaxConnection.credential(from: data(#"{"region":"cn"}"#))
            expect(false, "rejects a config without credentials")
        } catch ProviderConnectionError.signIn {
            expect(true, "rejects a config without credentials")
        }

        var captured: URLRequest?
        let fetched = try await MiniMaxConnection.fetch(
            credential: MiniMaxConnection.Credential(apiKey: "sk-request-test"),
            send: { request in
                captured = request
                return full
            }, now: now)
        expect(fetched.primary?.usedFraction == parsed.primary?.usedFraction,
               "fetches and parses a quota response")
        expect(captured?.url?.host == "api.minimaxi.com" && captured?.url?.path == "/v1/token_plan/remains",
               "uses the MiniMax CN quota endpoint")
        expect(captured?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-request-test",
               "sends the API key as a bearer token")

        if failures > 0 { exit(1) }
    }
}
