# Development Setup

Set up and verified on 2026-11-16 on Windows 11 (Intel i5-9300H, 16 GB memory).

## Installed tools

| Tool | Version | Location | Installed by |
|---|---|---|---|
| Godot Engine (standard, not .NET) | **4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`) | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\` | winget |
| Godot export templates | 4.7.2 stable (SHA-512 checked against the official release) | `%APPDATA%\Godot\export_templates\4.7.2.stable\` | Downloaded from the Godot GitHub release |
| OpenJDK (Microsoft build) | 17.0.21 | `C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot\` | winget |
| Android SDK command-line tools | `commandlinetools-win-15859902` (SHA-256 checked) | `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\` | Downloaded from Google |
| Android Studio | 2026.2.2.8 | Default install folder | winget |
| Git | 2.55.0 | `C:\Program Files\Git\` | Already installed |
| GitHub CLI (`gh`) | 2.104.0 | `C:\Program Files\GitHub CLI\` | winget |
| Node.js | already installed | `C:\Program Files\nodejs\` | Already installed (handy for serving the web build locally) |

**Pinned engine version: Godot 4.7.2.** Do not upgrade the engine mid-release without a decision; a new version can change export behaviour.

## Android SDK packages

Installed in `%LOCALAPPDATA%\Android\Sdk`. The Android SDK licences were accepted on 2026-11-16 with your permission.

| Package | Version | Why |
|---|---|---|
| `platform-tools` | 37.0.1 | `adb`, for installing on a phone |
| `build-tools;35.0.1` | 35.0.1 | Listed by the Godot 4.7 docs |
| `build-tools;36.0.0` | 36.0.0 | Godot 4.7 targets Android 16 (API 36) |
| `platforms;android-35` | 2 | Listed by the Godot 4.7 docs |
| `platforms;android-36` | 2 | Matches Godot 4.7's target |
| `cmake;3.10.2.4988404` | 3.10.2 | Required for Gradle builds |
| `ndk;28.1.13356709` | r28b | Required for Gradle builds |

## Environment (user level)

| Variable | Value |
|---|---|
| `JAVA_HOME` | `C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot` |
| `ANDROID_HOME` | `%LOCALAPPDATA%\Android\Sdk` |
| `Path` additions | `%LOCALAPPDATA%\Programs\bin` (holds `godot.cmd`), `%ANDROID_HOME%\platform-tools`, `%ANDROID_HOME%\cmdline-tools\latest\bin` |

Open a **new** terminal for these to take effect.

- `godot` in a terminal runs the console version of Godot 4.7.2 (for command-line exports and tests).
- The editor is in the Start Menu as **Godot 4.7.2**.

## Godot editor settings

Stored in `%APPDATA%\Godot\editor_settings-4.7.tres` (a backup of the original is next to it as `.bak`).

| Setting | Value |
|---|---|
| Export › Android › Java SDK Path | `C:/Program Files/Microsoft/jdk-17.0.21.21-hotspot` |
| Export › Android › Android SDK Path | `C:/Users/pravi/AppData/Local/Android/Sdk` |
| Export › Android › Debug Keystore | `%APPDATA%\Godot\keystores\debug.keystore` (standard Android debug values: user `androiddebugkey`, password `android`) |

The debug keystore is only for test builds on your own phone. The **release** keystore for Google Play is created later (BUILD_PLAN task 6.1) and must be backed up twice.

## Toolchain check (2026-11-16)

An empty test project (one label, Compatibility renderer) was exported from the command line.

| Build | Result | Size |
|---|---|---|
| Android debug APK, arm64 only | Built, signed with the debug key, targets Android 16 (API 36), minimum Android 7 (API 24) | **27 MB** |
| Web, no threads | Built | 38 MB on disk, **9.8 MB compressed** (what a phone actually downloads) |
| Android App Bundle via Gradle (Play Store format), checked 2026-11-19 | Built | **26.9 MB**. First run downloaded about 1.2 GB of Gradle files into `%USERPROFILE%\.gradle`; later builds reuse them |

What this tells the trial week:

- **Android size:** an empty project is already 27 MB, so the real game will land near the trial's 30 MB "pass" line. Expect a "worry" result and plan to trim the engine (a custom export template without 3D) if needed.
- **Web size:** about 10 MB compressed before any game content, comfortably under the 15 MB "pass" line.

Two project settings every Android export needs (the real project will include them):

- Rendering › Textures › VRAM Compression › **Import ETC2 ASTC** = on.
- Application › Config › **Icon** set (export works without it, but complains).

## Repository

- GitHub: https://github.com/claudecollab7-alt/no-name-mobile-game
- **Public** by your choice (2026-11-16). Everything committed is readable by anyone, so never commit keystores, passwords, API keys or private player data. The `.gitignore` already blocks keystores and `.env` files.
- Branch `main` tracks `origin/main`.

## Still to do by you

| Item | How |
|---|---|
| Sign in to the GitHub command-line tool | Optional: run `gh auth login` in a new terminal. Plain `git push` already works through Git's own saved sign-in. |
| First run of Android Studio | Choose **Custom** setup and keep the SDK location `%LOCALAPPDATA%\Android\Sdk`. Do not let it delete or move existing packages. Needed only if you want the phone emulator. |
| Phone ready | On the cheap test phone: Settings › About › tap "Build number" seven times, then Developer options › **USB debugging** on. Plug in and accept the prompt. `adb devices` should list it. |
| Godot tutorial | Official docs › Getting started › "Your first 2D game". |

## Reinstalling on another computer

```bash
winget install --id GodotEngine.GodotEngine -e --version 4.7.2
```

```bash
winget install --id Microsoft.OpenJDK.17 -e
```

```bash
winget install --id GitHub.cli -e
```

```bash
winget install --id Google.AndroidStudio -e
```

Then download the Android command-line tools from developer.android.com/studio, unpack them to `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest`, accept the licences, and install the packages in the table above. Download `Godot_v4.7.2-stable_export_templates.tpz` from the Godot 4.7.2 GitHub release and install it from the editor (Editor › Manage Export Templates › Install from File).
