import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: PhoenixSessionModel

    var body: some View {
        ZStack {
            PhoenixTheme.background.ignoresSafeArea()
            if let account = session.account {
                LauncherView(account: account)
            } else {
                LoginView()
            }
        }
        .foregroundStyle(PhoenixTheme.text)
    }
}

private struct LoginView: View {
    @EnvironmentObject private var session: PhoenixSessionModel
    @State private var showEmail = false
    @State private var register = false
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Image("PhoenixSplash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.58).ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer()
                Text("PHOENIX")
                    .font(.system(size: 32, weight: .black))
                    .tracking(5)
                Text("LAUNCHER")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(PhoenixTheme.orange)

                Spacer().frame(height: 20)
                Text("Вход в аккаунт")
                    .font(.title2.bold())
                Text("Один аккаунт для всех игр Phoenix")
                    .font(.subheadline)
                    .foregroundStyle(PhoenixTheme.muted)

                Spacer().frame(height: 12)

                Button {
                    session.loginWithTelegram()
                } label: {
                    Text(session.busy ? "Подключение…" : "✈  Войти через Telegram")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(PhoenixPrimaryButtonStyle())
                .disabled(session.busy)

                Button {
                    register = false
                    showEmail = true
                } label: {
                    Text("Войти по Email")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(PhoenixSecondaryButtonStyle())
                .disabled(session.busy)

                Button("Создать Phoenix Account") {
                    register = true
                    showEmail = true
                }
                .foregroundStyle(.blue)
                .disabled(session.busy)

                if let error = session.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(PhoenixTheme.danger)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .frame(maxWidth: 430)
            .padding(24)
        }
        .sheet(isPresented: $showEmail) {
            NavigationView {
                Form {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Пароль", text: $password)
                    Button(register ? "Создать аккаунт" : "Войти") {
                        Task {
                            await session.email(email: email, password: password, register: register)
                            if session.account != nil { showEmail = false }
                        }
                    }
                    .disabled(email.isEmpty || password.count < 8 || session.busy)
                }
                .navigationTitle(register ? "Phoenix Account" : "Вход по Email")
            }
        }
    }
}

private struct LauncherView: View {
    let account: PhoenixAccount
    @EnvironmentObject private var session: PhoenixSessionModel
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView(account: account)
                .tabItem { Label("Главная", systemImage: "house") }
                .tag(0)
            Text("Библиотека").tabItem { Label("Библиотека", systemImage: "square.grid.2x2") }.tag(1)
            Text("Новости").tabItem { Label("Новости", systemImage: "newspaper") }.tag(2)
            ProfileView(account: account)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
                .tag(3)
            Text("Настройки").tabItem { Label("Настройки", systemImage: "gearshape") }.tag(4)
        }
        .tint(PhoenixTheme.orange)
    }
}

private struct HomeView: View {
    let account: PhoenixAccount

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ТВОЯ ИГРОВАЯ ВСЕЛЕННАЯ")
                    .font(.caption2.bold())
                    .tracking(1.5)
                    .foregroundStyle(PhoenixTheme.muted)
                Text("Привет, \(account.nickname) ✦")
                    .font(.title2.bold())

                ZStack(alignment: .bottomLeading) {
                    Image("PPAHero").resizable().scaledToFill()
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ТВОЯ ЛЕГЕНДА НАЧИНАЕТСЯ ЗДЕСЬ")
                            .font(.caption2.bold())
                            .foregroundStyle(PhoenixTheme.orange)
                        Text("PHOENIX\nPIX ARENA")
                            .font(.system(size: 36, weight: .black))
                        Text("Стань частью нового мира. Собери клан. Зажги свою легенду на арене.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(20)
                }
                .frame(height: 470)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(PhoenixTheme.border))
            }
            .padding(20)
        }
        .background(PhoenixTheme.background)
    }
}

private struct ProfileView: View {
    let account: PhoenixAccount
    @EnvironmentObject private var session: PhoenixSessionModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(account.avatarLetter)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PhoenixTheme.orange)
                    .frame(width: 86, height: 86)
                    .background(PhoenixTheme.secondary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PhoenixTheme.orange.opacity(0.55)))
                Text(account.nickname).font(.largeTitle.bold())
                Text("Phoenix Account").foregroundStyle(PhoenixTheme.muted)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Telegram: " + (account.telegramUsername.map { "@\($0)" } ?? "привязан"))
                    Text("Email: " + (account.email ?? "не привязан"))
                    Text("PPA: " + (account.ppaNickname ?? "ожидает привязки Telegram"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(PhoenixTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Выйти из аккаунта") {
                    Task { await session.logout() }
                }
                .buttonStyle(PhoenixSecondaryButtonStyle())
            }
            .padding(20)
        }
        .background(PhoenixTheme.background)
    }
}

private struct PhoenixPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .background(PhoenixTheme.orange.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct PhoenixSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(PhoenixTheme.text)
            .background(PhoenixTheme.secondary.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(PhoenixTheme.border))
    }
}
