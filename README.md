<p align="center">
  <img src="assets/images/logo.png" width="120" alt="meshngr logo" />
</p>

<h1 align="center">meshngr</h1>

<p align="center">
  <strong>Beautiful mesh messaging for MeshCore LoRa radios.</strong><br>
  Off-grid. Encrypted. No internet required.
</p>

<p align="center">
  <a href="https://github.com/satsdisco/meshngr/releases/latest"><img src="https://img.shields.io/github/v/release/satsdisco/meshngr?style=flat-square&color=4A9EFF" alt="Latest Release"></a>
  <a href="https://github.com/satsdisco/meshngr/blob/main/LICENSE"><img src="https://img.shields.io/github/license/satsdisco/meshngr?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-green?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/MeshCore-compatible-orange?style=flat-square" alt="MeshCore">
</p>

---

## What is meshngr?

A mobile messaging app that connects to [MeshCore](https://meshcore.net) LoRa radios over Bluetooth. Send messages, join channels, discover nodes — all without internet, cell towers, or any centralized infrastructure.

Built for real people, not radio engineers. If you can use Telegram, you can use meshngr.

## Why

MeshCore's protocol is solid. The existing companion apps aren't great for everyday use — cluttered with technical details, hard to navigate, confusing for anyone who isn't already deep in mesh networking.

meshngr fixes that. Clean UI, plain English, zero jargon. The same protocol underneath, wrapped in software that doesn't get in the way.

## Features

- **Direct Messages** — encrypted end-to-end between two radios. Both parties exchange public keys (QR scan or paste)
- **Channels** — encrypted group conversations. Public, private, or hashtag channels. Up to 8 active at once
- **Contact Management** — save contacts from channels, QR codes, or by pasting public keys. Your radio's 200+ known nodes stay organized and out of the way
- **Node Discovery** — see who's on the mesh. Tap a sender name in any channel to view their profile, save them, or start a DM
- **Delivery Status** — see when your message is pending, sent, or failed. Tap to retry
- **Works Offline** — no internet, no servers, no accounts. Your radio is your identity

## Getting Started

### What you need

1. A **MeshCore companion radio** (like the Wio Tracker, Heltec V3, or T-Beam) flashed with MeshCore firmware
2. An **Android phone** (iOS coming soon via TestFlight)
3. **meshngr** — download the latest APK from [Releases](https://github.com/satsdisco/meshngr/releases/latest)

### First launch

1. Install the APK and open meshngr
2. Grant Bluetooth permissions when prompted
3. Turn on your MeshCore radio
4. meshngr will find your radio automatically — tap to connect
5. Your channels and contacts sync from the radio within seconds
6. Start messaging!

### Adding contacts

DMs require both people to have each other's public key. Three ways to exchange:

- **QR Code** — meet in person, scan each other's codes (tap the QR icon in the top bar)
- **Paste Public Key** — share your key over Signal/Telegram/email, paste theirs in the app (Contacts tab → + → Paste Public Key)
- **Channel Discovery** — tap someone's name in a channel message → Save Contact → Send DM

### Channels

Your radio supports 8 channel slots. Some common ones:

| Channel | What it is |
|---------|-----------|
| **Public** | The default channel everyone's on. Unencrypted broadcast |
| **#test** | Testing channel |
| Any **#hashtag** | Type a name, anyone using the same name can chat. Key is derived from the name |

To add a channel: Channels tab → + button → pick a type.

## Download

### Android
Download the latest APK from the [Releases](https://github.com/satsdisco/meshngr/releases/latest) page.

### iOS
Coming soon. Need an Apple Distribution certificate for TestFlight.

## Building from Source

```bash
# Prerequisites: Flutter 3.x, Android SDK, Xcode (for iOS)
git clone https://github.com/satsdisco/meshngr.git
cd meshngr
flutter pub get

# Android
flutter build apk --release

# iOS (requires signing)
flutter build ios --release
```

## Architecture

```
lib/
├── core/
│   ├── ble_service.dart      # BLE connection, scan, auto-reconnect
│   ├── protocol.dart         # MeshCore companion radio protocol
│   └── buffer.dart           # Byte reader/writer utilities
├── data/
│   └── database.dart         # SQLite persistence
├── models/
│   ├── contact.dart          # Contact with trust levels, node types
│   ├── message.dart          # Messages with delivery status, routing
│   ├── channel.dart          # Channel configuration
│   └── broadcast.dart        # Broadcast advertisements
├── providers/
│   └── chat_provider.dart    # State management (Provider)
├── screens/                  # All UI screens
├── widgets/                  # Reusable components
└── theme/
    └── app_theme.dart        # Dark theme, Material 3
```

### MeshCore Protocol

meshngr communicates with your radio over BLE UART (Nordic UART Service). The protocol is documented on the [MeshCore wiki](https://github.com/meshcore-dev/MeshCore/wiki/Companion-Radio-Protocol).

Key characteristics:
- **Binary frames** over BLE characteristic writes
- **8 channel slots** with PSK encryption
- **Public key identity** — your radio's keypair is your identity
- **Hybrid routing** — messages find the best path through the mesh automatically

## Security

- All DMs are encrypted end-to-end using the recipient's public key
- Channel messages are encrypted with a shared pre-shared key (PSK)
- No data leaves your phone except over LoRa through your radio
- No accounts, no servers, no telemetry, no analytics
- Your identity is your radio's keypair — meshngr doesn't create or store additional keys
- Local SQLite database for message history (on-device only)

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

This is an early-stage project. The biggest impact areas right now:
- Testing with different MeshCore radios and firmware versions
- UX feedback from non-technical users
- iOS testing (if you have an Apple developer account)
- Protocol edge cases and error handling

## Credits

- [MeshCore](https://meshcore.net) — the mesh networking firmware and protocol
- [meshcore-open-ref](https://github.com/meshcore-community/meshcore-open-ref) — community reference app that helped decode the protocol
- Built with [Flutter](https://flutter.dev) and [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus)

## License

MIT — see [LICENSE](LICENSE) for details.
