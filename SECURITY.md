# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in meshngr, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, email: **security@meshngr.org** (or open a private security advisory on GitHub)

We'll acknowledge receipt within 48 hours and work with you on a fix before any public disclosure.

## Scope

meshngr is a companion app for MeshCore radios. The security boundary includes:

- **BLE communication** between the phone and radio
- **Local data storage** (SQLite database on device)
- **QR code generation and scanning** (contact exchange)
- **UI-level data handling** (displaying messages, contacts, keys)

The following are **out of scope** for meshngr (handled by MeshCore firmware):

- LoRa radio encryption and key exchange
- Mesh routing and packet handling
- Radio firmware vulnerabilities

## Security Model

- **No network access** — meshngr does not connect to the internet. All communication happens over BLE to your local radio.
- **No accounts** — your identity is your radio's keypair. meshngr doesn't create accounts or contact external servers.
- **No telemetry** — no analytics, crash reporting, or usage tracking.
- **Local storage only** — messages and contacts are stored in a local SQLite database on your device.
- **Open source** — the full source code is available for audit.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Older releases | ❌ |

We recommend always using the latest release.
