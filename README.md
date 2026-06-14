# TorBox CDN Menu

A macOS menu bar app to quickly switch your [TorBox](https://torbox.app) CDN selection.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Features

- Menu bar icon for instant CDN switching
- Credentials stored securely in macOS Keychain
- Auto-login on subsequent launches
- All 20 TorBox CDN regions supported

## Install

Download `TorBoxCDN.zip` from [Releases](../../releases), unzip, and drag to `/Applications`.

On first launch, right-click → Open (unsigned app).

## Build from source

```bash
swift build -c release
./build-app.sh
```

The app bundle will be at `.build/release/TorBoxCDN.app`.

## Usage

1. Click the 🌐 icon in your menu bar
2. Login with your TorBox email/password (stored in Keychain)
3. Select a CDN from the dropdown

## License

MIT
