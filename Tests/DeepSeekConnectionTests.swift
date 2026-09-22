import Foundation

@main
struct DeepSeekConnectionTests {
    static var failures = 0

    static func expect(_ value: Bool, _ label: String) {
        if value { print("PASS \(label)") } else { failures += 1; print("FAIL \(label)") }
    }

    static func data(_ text: String) -> Data { Data(text.utf8) }

    static func main() async throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let payload = data(#"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"110.00","granted_balance":"10.00","topped_up_balance":"100.00"}]}"#)
        let parsed = try DeepSeekConnection.parse(payload, now: now)
        expect(parsed.balanceAvailable == true, "reads wallet availability")
        expect(parsed.primaryBalance?.currency == "CNY", "reads the wallet currency")
        expect(parsed.primaryBalance?.total == Decimal(110), "reads the total balance")
        expect(parsed.primaryBalance?.granted == Decimal(10), "reads the granted balance")
        expect(parsed.primaryBalance?.toppedUp == Decimal(100), "reads the topped-up balance")
        expect(parsed.updatedAt == now, "records the fetch time")

        let zero = try DeepSeekConnection.parse(data(#"{"is_available":false,"balance_infos":[{"currency":"USD","total_balance":"0.00","granted_balance":"0.00","topped_up_balance":"0.00"}]}"#))
        expect(zero.primaryBalance?.total == 0, "zero balance remains a real reading")
        expect(zero.balanceAvailable == false, "preserves unavailable wallet state")

        do {
            _ = try DeepSeekConnection.parse(data(#"{"is_available":true,"balance_infos":[]}"#))
            expect(false, "rejects a response without balances")
        } catch ProviderConnectionError.invalidResponse {
            expect(true, "rejects a response without balances")
        }

        let plain = try DeepSeekConnection.credential(from: data("""
        version: 1
        refs:
          DEEPSEEK_API_KEY: sk-deepseek-test
        records: {}
        """))
        expect(plain.apiKey == "sk-deepseek-test", "reads the Harness credential store")
        let quoted = try DeepSeekConnection.credential(from: data("""
        refs:
          DEEPSEEK_API_KEY: "sk-quoted-test"
        """))
        expect(quoted.apiKey == "sk-quoted-test", "reads a quoted Harness credential")
        do {
            _ = try DeepSeekConnection.credential(from: data("version: 1\nrefs: {}\n"))
            expect(false, "rejects a store without a DeepSeek API key")
        } catch ProviderConnectionError.signIn {
            expect(true, "rejects a store without a DeepSeek API key")
        }

        var captured: URLRequest?
        let fetched = try await DeepSeekConnection.fetch(
            credential: DeepSeekConnection.Credential(apiKey: "sk-request-test"),
            send: { request in
                captured = request
                return payload
            }, now: now)
        expect(fetched.primaryBalance?.total == Decimal(110), "fetches and parses a wallet response")
        expect(captured?.url?.host == "api.deepseek.com" && captured?.url?.path == "/user/balance",
               "uses the official DeepSeek balance endpoint")
        expect(captured?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-request-test",
               "sends the API key as a bearer token")

        if failures > 0 { exit(1) }
    }
}
