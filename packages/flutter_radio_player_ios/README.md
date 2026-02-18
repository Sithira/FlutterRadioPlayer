# flutter_radio_player_ios

The iOS implementation of [`flutter_radio_player`](https://pub.dev/packages/flutter_radio_player).

## Usage

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin) and will be automatically included in your app when you depend on `flutter_radio_player`. There is no need to add it to your `pubspec.yaml` explicitly.

## Implementation

Uses AVFoundation directly (no third-party dependencies) with `AVPlayerItemMetadataOutput` for ICY metadata extraction and `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` for lock screen controls.

Minimum deployment target: iOS 14.0
