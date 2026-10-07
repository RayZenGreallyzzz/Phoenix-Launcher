import SwiftUI
import TelegramLogin

@main
struct PhoenixLauncherApp: App {
    @StateObject private var session = PhoenixSessionModel()

    init() {
        TelegramLogin.configure(
            clientId: "8476557926",
            redirectUri: "https://app2153925360-login.tg.dev",
            scopes: ["profile"]
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .task { await session.restore() }
                .onOpenURL { url in
                    guard url.host == "app2153925360-login.tg.dev" else { return }
                    TelegramLogin.handle(url)
                }
        }
    }
}
