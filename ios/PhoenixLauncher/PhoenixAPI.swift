import Foundation
import Security

struct PhoenixAccount: Codable, Equatable {
    let accountId: String
    let telegramId: String?
    let email: String?
    let emailVerified: Bool
    let nickname: String
    let ppaNickname: String?
    let classKey: String
    let telegramUsername: String?
    let firstName: String
    let lastName: String
    let createdAt: Int64

    var avatarLetter: String {
        String(nickname.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "P").uppercased()
    }
}

private struct PhoenixSessionPayload: Codable {
    let token: String
    let expiresAt: Int64
}

private struct PhoenixAuthResponse: Codable {
    let ok: Bool
    let session: PhoenixSessionPayload
    let account: PhoenixAccount
}

private struct PhoenixMeResponse: Codable {
    let ok: Bool
    let account: PhoenixAccount
}

private struct PhoenixErrorResponse: Codable {
    let ok: Bool?
    let code: String?
    let message: String?
}

enum PhoenixAPIError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return "Некорректный ответ Phoenix Server"
        }
    }
}

actor PhoenixAPI {
    static let shared = PhoenixAPI()

    private let baseURL = URL(string: "https://ppa-phoenixpixarena.1988stella1988.workers.dev")!
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func restoreSession() async throws -> PhoenixAccount? {
        guard let token = KeychainStore.sessionToken else { return nil }
        do {
            let response: PhoenixMeResponse = try await request(path: "/api/launcher/me", method: "GET", bearer: token)
            return response.account
        } catch {
            KeychainStore.sessionToken = nil
            throw error
        }
    }

    func exchangeTelegram(idToken: String) async throws -> PhoenixAccount {
        let body = try encoder.encode(["idToken": idToken])
        let response: PhoenixAuthResponse = try await request(
            path: "/api/launcher/auth/telegram/native",
            method: "POST",
            body: body,
            bearer: KeychainStore.sessionToken
        )
        KeychainStore.sessionToken = response.session.token
        return response.account
    }

    func emailLogin(email: String, password: String, register: Bool) async throws -> PhoenixAccount {
        let body = try encoder.encode(["email": email, "password": password])
        let path = register ? "/api/launcher/email/register" : "/api/launcher/email/login"
        let response: PhoenixAuthResponse = try await request(path: path, method: "POST", body: body)
        KeychainStore.sessionToken = response.session.token
        return response.account
    }

    func bindEmail(email: String, password: String) async throws -> PhoenixAccount {
        guard let token = KeychainStore.sessionToken else {
            throw PhoenixAPIError.server("Сессия Phoenix не найдена")
        }
        let body = try encoder.encode(["email": email, "password": password])
        let response: PhoenixMeResponse = try await request(
            path: "/api/launcher/email/bind",
            method: "POST",
            body: body,
            bearer: token
        )
        return response.account
    }

    func logout() async {
        if let token = KeychainStore.sessionToken {
            _ = try? await requestRaw(path: "/api/launcher/logout", method: "POST", body: Data("{}".utf8), bearer: token)
        }
        KeychainStore.sessionToken = nil
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        body: Data? = nil,
        bearer: String? = nil
    ) async throws -> T {
        let data = try await requestRaw(path: path, method: method, body: body, bearer: bearer)
        guard let value = try? decoder.decode(T.self, from: data) else {
            throw PhoenixAPIError.invalidResponse
        }
        return value
    }

    private func requestRaw(
        path: String,
        method: String,
        body: Data? = nil,
        bearer: String? = nil
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PhoenixAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? decoder.decode(PhoenixErrorResponse.self, from: data)
            throw PhoenixAPIError.server(error?.message ?? "Phoenix Server HTTP \(http.statusCode)")
        }
        return data
    }
}

enum KeychainStore {
    private static let service = "com.phoenixgames.launcher"
    private static let account = "phoenix-session-token"

    static var sessionToken: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data
            else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let base: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(base as CFDictionary)
            guard let newValue, let data = newValue.data(using: .utf8) else { return }
            var add = base
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
