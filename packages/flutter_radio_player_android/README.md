# flutter_radio_player_android

The Android implementation of [`flutter_radio_player`](https://pub.dev/packages/flutter_radio_player).

## Usage

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin) and will be automatically included in your app when you depend on `flutter_radio_player`. There is no need to add it to your `pubspec.yaml` explicitly.

## Implementation

Uses [AndroidX Media3](https://developer.android.com/media/media3) (ExoPlayer) with a `MediaLibraryService` for background playback, notification controls, and ICY metadata extraction.

Minimum SDK: 21
