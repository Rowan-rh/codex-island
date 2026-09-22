import Foundation

/// Reads DeepSeek API wallet balances without writing or refreshing credentials.
enum DeepSeekConnection {
    struct Credential {
        let apiKey: String
    }

    private static let apiKeyEnvironment = "DEEPSEEK_API_KEY"
    private static let harnessHomeEnvironment = "DSH_HOME"
    private static let endpoint = "https://api.deepseek.com/user/balance"

    static func fetch() async throws -> ConnectedUsage {
        let credential = try await Task.detached(priority: .utility) {
            try credentialFromEnvironmentOrHarness()
        }.value
        try Task.checkCancellation()
        return try await fetch(credential: credential, send: send)
    }

    static func fetch(credential: Credential,
                      send: (URLRequest) async throws -> Data,
                      now: Date = Date()) async throws -> ConnectedUsage {
        let usage = try parse(try await send(request(credential: credential)), now: now)
        try Task.checkCancellation()
        return usage
    }

    static func parse(_ data: Data, now: Date = Date()) throws -> ConnectedUsage {
        guard data.count <= 1_048_576 else { throw ProviderConnectionError.invalidResponse }
        let response = try JSONDecoder().decode(BalanceResponse.self, from: data)
        let balances = response.balanceInfos.compactMap { info -> ConnectedBalance? in
            let currency = info.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard currency.count == 3,
                  let total = decimal(info.totalBalance),
                  let granted = decimal(info.grantedBalance),
                  let toppedUp = decimal(info.toppedUpBalance),
                  total >= 0, granted >= 0, toppedUp >= 0 else { return nil }
            return ConnectedBalance(currency: currency, total: total, granted: granted, toppedUp: toppedUp)
        }
        guard !balances.isEmpty else { throw ProviderConnectionError.invalidResponse }
        return ConnectedUsage(
            balances: balances,
            balanceAvailable: response.isAvailable,
            updatedAt: now
        )
    }

    static func credential(from data: Data) throws -> Credential {
        guard data.count <= 1_048_576,
              let text = String(data: data, encoding: .utf8) else {
            throw ProviderConnectionError.invalidResponse
        }
        let lines = text.components(separatedBy: .newlines)
        var refsIndent: Int?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let indent = line.prefix { $0 == " " }.count
            if refsIndent == nil {
                if trimmed == "refs:" { refsIndent = indent }
                continue
            }
            guard let refsIndent else { continue }
            if indent <= refsIndent { break }
            guard trimmed.hasPrefix("\(apiKeyEnvironment):") else { continue }
            let raw = String(trimmed.dropFirst(apiKeyEnvironment.count + 1))
            return try credential(apiKey: yamlScalar(raw))
        }
        throw ProviderConnectionError.signIn
    }

    private static func credentialFromEnvironmentOrHarness() throws -> Credential {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment[apiKeyEnvironment], let credential = try? credential(apiKey: value) {
            return credential
        }

        let home: URL
        if let configured = environment[harnessHomeEnvironment], !configured.isEmpty {
            let expanded = NSString(string: configured).expandingTildeInPath
            home = URL(fileURLWithPath: expanded, isDirectory: true)
        } else {
            home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".dsh", isDirectory: true)
        }
        let file = home.appendingPathComponent(".credentials.yaml")
        guard let data = try? Data(contentsOf: file) else { throw ProviderConnectionError.signIn }
        return try credential(from: data)
    }

    private static func credential(apiKey: String) throws -> Credential {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ProviderConnectionError.signIn }
        return Credential(apiKey: value)
    }

    private static func yamlScalar(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespaces)
        if value.count >= 2, value.first == "'", value.last == "'" {
            return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }
        if value.count >= 2, value.first == "\"", value.last == "\"",
           let data = value.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }
        return value.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
    }

    private static func decimal(_ raw: String) -> Decimal? {
        Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func request(credential: Credential) throws -> URLRequest {
        guard let url = URL(string: endpoint) else { throw ProviderConnectionError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let session = URLSession(configuration: .ephemeral,
                                 delegate: DeepSeekNoProviderRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ProviderConnectionError.invalidResponse }
        if response.statusCode == 401 { throw ProviderConnectionError.signIn }
        guard response.statusCode == 200 else { throw ProviderConnectionError.http(response.statusCode) }
        guard data.count <= 1_048_576 else { throw ProviderConnectionError.invalidResponse }
        return data
    }

    private struct BalanceResponse: Decodable {
        let isAvailable: Bool
        let balanceInfos: [BalanceInfo]

        enum CodingKeys: String, CodingKey {
            case isAvailable = "is_available"
            case balanceInfos = "balance_infos"
        }
    }

    private struct BalanceInfo: Decodable {
        let currency: String
        let totalBalance: String
        let grantedBalance: String
        let toppedUpBalance: String

        enum CodingKeys: String, CodingKey {
            case currency
            case totalBalance = "total_balance"
            case grantedBalance = "granted_balance"
            case toppedUpBalance = "topped_up_balance"
        }
    }
}

private final class DeepSeekNoProviderRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
