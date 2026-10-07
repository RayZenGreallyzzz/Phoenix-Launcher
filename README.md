# Phoenix Launcher

Native Android launcher prototype for the Phoenix game ecosystem.

## Architecture locked for growth

- **Launcher UI:** Kotlin + Jetpack Compose
- **Games:** independent modules; Phoenix Pix Arena is the first one
- **Account:** future Phoenix `accountId`, with Telegram as a linked login method
- **Updates:** each game will expose its own manifest/version/package data
- **Game runtime:** planned Godot Android module for PPA, without embedding the current Telegram WebView

## Current prototype

The first build implements the approved visual direction:

- Phoenix splash
- Login / registration shell
- Home with Phoenix Pix Arena hero card
- Library
- News
- Profile
- Settings
- Game details
- Download / verification / installation screen

The download progress is intentionally simulated until the real game manifest/update endpoint is connected.

## Build

Requires Android SDK 37 and JDK 17+.

```bash
gradle assembleDebug
```

APK output:

`app/build/outputs/apk/debug/app-debug.apk`

A GitHub Actions workflow is included and will upload the debug APK as a build artifact on every push to `main`.

> The repository CI pins Gradle 9.6.0. Android Studio can sync and build the project directly.
