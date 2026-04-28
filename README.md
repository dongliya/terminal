# Terminal

A modern SSH terminal client for Android, built with Flutter and Rust.

## Features

- 🔐 **SSH Connections** - Password and private key authentication
- 📁 **SFTP File Manager** - Browse, upload, download, and manage remote files
- 🌐 **Multi-language** - English and Chinese localization
- 🎨 **Material Design 3** - Dark theme with modern UI
- ⌨️ **Terminal Emulator** - Full-featured terminal with special keys
- 📋 **Connection Logs** - Debug and monitor SSH sessions
- 💾 **Saved Hosts** - Manage multiple server profiles

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **Rust** - High-performance SSH implementation via `flutter_rust_bridge`
- **xterm.dart** - Terminal emulation
- **Material 3** - Modern UI components

## Screenshots

| Connections | Terminal | SFTP Files |
|-------------|----------|------------|
| ![Connections](docs/screenshots/connections.png) | ![Terminal](docs/screenshots/terminal.png) | ![SFTP](docs/screenshots/sftp.png) |

## Installation

### Download APK

Get the latest release APK from the [releases](releases/) directory or [GitHub Releases](https://github.com/your-username/terminal/releases).

```bash
# Install via ADB
adb install releases/app-release.apk
```

### Build from Source

#### Prerequisites

- Flutter SDK (>= 3.11.4)
- Rust toolchain
- Android SDK (for Android builds)

#### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/terminal.git
cd terminal

# Install Flutter dependencies
flutter pub get

# Build Rust library (automatic with flutter_rust_bridge)
flutter build apk --release
```

#### Development

```bash
# Run in debug mode
flutter run

# Run tests
flutter test

# Generate localization files
flutter gen-l10n
```

## Project Structure

```
terminal/
├── lib/
│   ├── l10n/              # Localization files
│   ├── src/
│   │   ├── models/        # Data models
│   │   ├── rust/          # Rust bridge bindings
│   │   ├── screens/       # UI screens
│   │   └── services/      # Business logic
│   └── main.dart          # App entry point
├── rust/                  # Rust source code
├── rust_builder/          # Flutter-Rust bridge builder
├── android/               # Android platform code
├── ios/                   # iOS platform code
└── releases/              # Release APKs
```

## Configuration

### Add a Connection

1. Tap **Add Host** on the connections screen
2. Enter connection details:
   - **Name** - Display name for the server
   - **Host** - Server address (e.g., `example.com`)
   - **Username** - SSH username
   - **Port** - SSH port (default: 22)
3. Choose authentication method:
   - **Password** - Enter your password
   - **Private Key** - Paste your SSH private key
4. Tap **Test** to verify the connection
5. Tap **Save** to store the connection

### Special Keys

The terminal includes quick-access buttons for:
- Tab, Arrow keys, Ctrl, Esc
- Function keys (F1-F12)
- Copy, Clear screen

## Development

### Rust Bridge

This project uses `flutter_rust_bridge` to integrate Rust code:

```bash
# Regenerate bridge code
flutter_rust_bridge_codegen generate
```

### Localization

Add new strings in `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`:

```bash
flutter gen-l10n
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge) - Rust/Flutter integration
- [xterm.dart](https://pub.dev/packages/xterm) - Terminal emulator
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local storage
