# Phoenix Launcher platform architecture

Phoenix Launcher is one product with native clients per platform and one Phoenix account/backend.

## Identity

- Telegram Login Client ID: `8476557926`
- Telegram App URL / verified login domain: `https://app2153925360-login.tg.dev`
- Android package: `com.phoenixgames.launcher`
- iOS bundle ID: `com.phoenixgames.launcher`
- Phoenix backend: `https://ppa-phoenixpixarena.1988stella1988.workers.dev`

The client secret never ships in Android or iOS builds.

## Android

- Kotlin + Jetpack Compose.
- Official Telegram Login Android SDK source is pinned to TelegramMessenger/telegram-login-android commit
  `f9d5ec36ba2433bc5f103b5cd8289f43a05f9336`.
- Login callback is the verified Android App Link:
  `https://app2153925360-login.tg.dev/tglogin`.
- Telegram returns an OpenID Connect `id_token`; the launcher forwards it to
  `POST /api/launcher/auth/telegram/native`.
- The backend validates the JWT signature and audience before creating a Phoenix session.

## iOS / iPadOS

- Swift + SwiftUI, minimum iOS 15.
- Official TelegramLogin Swift package is pinned to commit
  `215851df7e3cd32787a0054e5d1a97d7aa62796e`.
- Uses the same Client ID and Phoenix backend as Android.
- The session token is stored in Keychain.
- Universal Links use `applinks:app2153925360-login.tg.dev`.

Before physical-device Telegram login can work on iPhone/iPad, register another Native App in BotFather:
- platform: iOS
- Bundle ID: `com.phoenixgames.launcher`
- Apple Team ID: the 10-character Team ID from the Apple Developer account

No Team ID is required for simulator compilation.

## Phoenix Account / PPA compatibility

Phoenix accounts are a layer above the existing PPA identity. PPA save data remains keyed by Telegram ID.

A Telegram login:
1. Telegram authenticates the user natively.
2. Phoenix backend validates Telegram's `id_token`.
3. Telegram ID maps to the existing PPA `players.telegram_id`.
4. Existing PPA nickname/class/save remain authoritative.
5. Phoenix returns a platform-independent session token and account payload.

Email/password is an additional Phoenix Account login. When a user signs in by email and later links the Telegram account that already owns PPA data, the backend merges the email credentials into the Telegram-backed Phoenix Account rather than creating a second game profile.

## Shared API contract

Both Android and iOS call the same routes:

- `POST /api/launcher/auth/telegram/native`
- `POST /api/launcher/email/register`
- `POST /api/launcher/email/login`
- `POST /api/launcher/email/bind`
- `GET /api/launcher/me`
- `POST /api/launcher/logout`

The same account payload drives greeting, avatar letter, profile, PPA nickname and linked-account state on both platforms.
