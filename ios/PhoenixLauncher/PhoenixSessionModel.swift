import Foundation
import TelegramLogin

@MainActor
final class PhoenixSessionModel: ObservableObject {
    @Published var account: PhoenixAccount?
    @Published var busy = false
    @Published var error: String?

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            account = try await PhoenixAPI.shared.restoreSession()
        } catch {
            account = nil
        }
    }

    func loginWithTelegram() {
        guard !busy else { return }
        busy = true
        error = nil

        TelegramLogin.login { result in
            Task { @MainActor in
                switch result {
                case .success(let data):
                    do {
                        self.account = try await PhoenixAPI.shared.exchangeTelegram(idToken: data.idToken)
                    } catch {
                        self.error = error.localizedDescription
                    }
                case .failure(let error):
                    self.error = error.localizedDescription
                }
                self.busy = false
            }
        }
    }

    func email(email: String, password: String, register: Bool) async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            account = try await PhoenixAPI.shared.emailLogin(email: email, password: password, register: register)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() async {
        busy = true
        await PhoenixAPI.shared.logout()
        account = nil
        error = nil
        busy = false
    }
}
