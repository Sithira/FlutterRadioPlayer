# Migration Guide

## Migrating from v3.x to v4.x

v4 is a full rewrite using a federated plugin architecture with Pigeon for type-safe platform channels.

### Installation

The package name is unchanged. Update your dependency:

```yaml
dependencies:
  flutter_radio_player: ^4.0.0
```

### Breaking Changes

#### 1. Typed sources (replaces raw maps)

```diff
- await player.initialize([
-   {"url": "https://example.com/stream", "title": "My Station"},
-   {"url": "https://example.com/stream2"},
- ], true);

+ await player.initialize([
+   const RadioSource(url: 'https://example.com/stream', title: 'My Station'),
+   const RadioSource(url: 'https://example.com/stream2'),
+ ], playWhenReady: true);
```

`RadioSource` supports three fields:

| Field     | Type      | Description                          |
|-----------|-----------|--------------------------------------|
| `url`     | `String`  | Stream URL (required)                |
| `title`   | `String?` | Display name for lock screen         |
| `artwork` | `String?` | Asset path or URL for album artwork  |

#### 2. Renamed stream getters

Stream getters are now simple properties instead of method calls:

```diff
- player.getPlaybackStream().listen((isPlaying) { ... });
+ player.isPlayingStream.listen((isPlaying) { ... });

- player.getNowPlayingStream().listen((title) { ... });
+ player.nowPlayingStream.listen((NowPlayingInfo info) {
+   print(info.title);
+ });

- player.getDeviceVolumeChangedStream().listen((volume) { ... });
+ player.volumeStream.listen((VolumeInfo vol) {
+   print('${vol.volume}, muted: ${vol.isMuted}');
+ });
```

> **Note:** `nowPlayingStream` now emits `NowPlayingInfo` objects instead of raw strings. `volumeStream` emits `VolumeInfo` objects with both volume level and mute state.

#### 3. Renamed methods

```diff
- await player.prevSource();
+ await player.previousSource();
```

#### 4. Volume return type

```diff
- double? volume = await player.getVolume(); // nullable
+ double volume = await player.getVolume();  // non-nullable
```

### New in v4

| Feature | Description |
|---------|-------------|
| `playOrPause()` | Toggle method that works on both Android and iOS |
| `dispose()` | Properly release native resources when done |
| Artwork URLs | `RadioSource.artwork` now accepts both asset paths and remote URLs |
| ICY metadata | Automatic extraction on both platforms via `nowPlayingStream` |

### Platform changes

#### iOS
- Minimum deployment target raised from 12.0 to **14.0**
- SwiftAudioEx dependency removed (now uses AVFoundation directly)
- Swift Package Manager supported alongside CocoaPods

#### Android
- kotlinx-serialization dependency removed
- Uses Media3/ExoPlayer for playback
- `compileSdk` 35, `minSdk` 21
