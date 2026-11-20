# Migration Guide

## Migrating from v4.x to v5.0 (pre-release)

5.0 replaces the 4.x API; there is no compatibility layer. The 4.2 additions (`FlutterRadioPlayer.instance`, `state`, `stateStream`, `RadioPlayerState`, `PlaybackStatus`, `RadioPlayerError`) keep their names and meaning, so code that already uses them moves over with few changes.

### Build requirements

| | 4.x | 5.0 |
|---|---|---|
| Flutter / Dart | 3.3 / 3.4 | 3.44 / 3.12 |
| Android | minSdk 21 | minSdk 24, Java 17, built-in Kotlin supported |
| iOS | 14 | 15 (raise `IPHONEOS_DEPLOYMENT_TARGET` and the Podfile `platform` if your app is older) |

### API

| 4.x | 5.0 |
|---|---|
| `FlutterRadioPlayer()` | `FlutterRadioPlayer.instance` (no public constructor) |
| `initialize(sources, playWhenReady: true)` | `setSources(sources, autoPlay: true)`; keeps a playing station that is still in the list and connects nothing until playback is requested |
| `jumpToSourceAtIndex(i)` | `play(index: i)` (always plays; out of range throws `RangeError`) |
| `nextSource()` / `previousSource()` | `next()` / `previous()` (keep the play state; wrap per `RadioPlayerOptions.wrapAround`) |
| `dispose()` | removed; use `stop()` to end playback, `setSources([])` to also clear the list |
| `isPlayingStream` | `state.isPlaying` (true while loading; `state.status == PlaybackStatus.playing` for audible) |
| `nowPlayingStream` | `state.nowPlaying` (`null` until the stream sends a title; never the station title) |
| `volumeStream`, `getVolume()`, `VolumeInfo` | `state.volume` |
| `StreamBuilder` over the streams | `RadioPlayerBuilder`, `ValueListenableBuilder(valueListenable: player, ...)`, or `stateStream` |
| default volume 0.5 | 1.0 |
| (none) | `stop()`, `setOptions(RadioPlayerOptions(...))` |

`RadioSource` gains `id` (defaults to `url`) and `headers`. `NowPlayingInfo.title` is non-null and gains `artist` and `song`. `RadioPlayerState` gains `sources`, `isPlaying`, `isLoading` and `isReconnecting`; `currentSource` is now a getter.

Tests: replace mock platforms with `FakeRadioPlayer.install()` from `package:flutter_radio_player/testing.dart`.

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
- `compileSdk` 36, `minSdk` 21
