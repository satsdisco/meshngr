# Contributing to meshngr

Thanks for wanting to help! meshngr is early-stage and contributions of all kinds are welcome.

## Ways to Contribute

### Testing
The most valuable contribution right now is real-world testing:
- Try the app with your MeshCore radio and report bugs
- Test with different radio hardware (Wio Tracker, Heltec V3, T-Beam, etc.)
- Test with different MeshCore firmware versions
- Give UX feedback — especially if you're not a radio/tech person

### Bug Reports
Open an issue with:
- What you expected to happen
- What actually happened
- Your radio hardware and firmware version
- Android/iOS version
- Screenshots if relevant

### Code
1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Make your changes
4. Test that the app builds (`flutter build apk --release`)
5. Commit with a clear message
6. Open a PR against `main`

### Design
We're always looking to improve the UX. If you have design ideas, mockups, or feedback — open an issue or discussion.

## Development Setup

```bash
# Install Flutter: https://docs.flutter.dev/get-started/install
# Clone the repo
git clone https://github.com/satsdisco/meshngr.git
cd meshngr
flutter pub get

# Run on connected device or emulator
flutter run

# Build release APK
flutter build apk --release
```

## Code Style

- Follow standard Dart/Flutter conventions
- Keep files focused — one screen per file, one widget per file where practical
- Provider for state management (may migrate to Riverpod later)
- Dark theme only (for now)
- Plain English in the UI — no radio jargon

## Questions?

Open a GitHub issue or discussion. We're friendly.
