# Flutter Radio Player

[![Pub Version](https://img.shields.io/pub/v/flutter_radio_player)](https://pub.dev/packages/flutter_radio_player)
[![Pub Likes](https://img.shields.io/pub/likes/flutter_radio_player)](https://pub.dev/packages/flutter_radio_player)
[![Pub Points](https://img.shields.io/pub/points/flutter_radio_player)](https://pub.dev/packages/flutter_radio_player)
[![CI](https://github.com/Sithira/FlutterRadioPlayer/actions/workflows/ci.yml/badge.svg)](https://github.com/Sithira/FlutterRadioPlayer/actions/workflows/ci.yml)

A Flutter plugin for playing streaming radio URLs with background playback, lock screen controls, and platform-native media integrations including watchOS, WearOS, CarPlay, and Android Auto.

|             | Android | iOS     |
|-------------|---------|---------|
| **Support** | SDK 21+ | iOS 14+ |

## Features

- Background audio playback with no extra configuration
- Lock screen and notification media controls
- ICY/stream metadata extraction
- Multiple source queue with next/previous/jump-to navigation
- Volume control with stream updates
- watchOS, WearOS, CarPlay, and Android Auto integration

## Getting Started

### Installation

```bash
flutter pub add flutter_radio_player
```

### Usage

```dart
import 'package:flutter_radio_player/flutter_radio_player.dart';

final player = FlutterRadioPlayer();

// Initialize with sources
await player.initialize(
  [
    const RadioSource(url: 'https://s2-webradio.antenne.de/chillout?icy=https'),
    const RadioSource(
      url: 'https://radio.lotustechnologieslk.net:2020/stream/sunfmgarden?icy=https',
      title: 'SunFM - Sri Lanka',
      artwork: 'images/sample-cover.jpg', // bundled asset
    ),
    const RadioSource(url: 'http://stream.riverradio.com:8000/wcvofm.aac'),
  ],
  playWhenReady: true,
);
```

### Controlling Playback

```dart
await player.play();
await player.pause();
await player.playOrPause();
await player.nextSource();
await player.previousSource();
await player.jumpToSourceAtIndex(1);
await player.setVolume(0.8);
final volume = await player.getVolume();
await player.dispose();
```

### Listening to Streams

```dart
player.isPlayingStream.listen((bool isPlaying) {
  print('Playing: $isPlaying');
});

player.nowPlayingStream.listen((NowPlayingInfo info) {
  print('Now playing: ${info.title}');
});

player.volumeStream.listen((VolumeInfo vol) {
  print('Volume: ${vol.volume}, Muted: ${vol.isMuted}');
});
```

## Player State

`FlutterRadioPlayer.instance` is a shared player. `FlutterRadioPlayer()` still works, but every instance drives the same native player, so the shared instance is a convenience, not isolation.

`state` is the latest snapshot of the player and `stateStream` emits a new snapshot on every change. A listener that subscribes to `stateStream` first receives the latest snapshot (if one has arrived), then live updates.

```dart
final player = FlutterRadioPlayer.instance;

StreamBuilder<RadioPlayerState>(
  initialData: player.state,
  stream: player.stateStream,
  builder: (context, snapshot) {
    final state = snapshot.requireData;
    return Text('${state.status.name} - ${state.currentSource?.title}');
  },
);
```

| Field           | Type                | Description                                                 |
|-----------------|---------------------|-------------------------------------------------------------|
| `status`        | `PlaybackStatus`    | See the table below                                         |
| `currentIndex`  | `int?`              | Index of the current source, `null` when nothing is loaded  |
| `currentSource` | `RadioSource?`      | The source at `currentIndex`, `null` when nothing is loaded |
| `nowPlaying`    | `NowPlayingInfo?`   | Track title, `null` when none is known                      |
| `volume`        | `double`            | Playback volume, 0.0 to 1.0                                 |
| `error`         | `RadioPlayerError?` | The pending playback error, `null` when there is none       |

| Status    | Meaning                                                                                  |
|-----------|------------------------------------------------------------------------------------------|
| `idle`    | No sources are loaded, or the player was disposed                                        |
| `loading` | Playback was requested and is not audible yet (connecting or buffering)                  |
| `playing` | Audio is playing                                                                         |
| `paused`  | Sources are loaded and playback was not requested (or is suppressed)                     |
| `error`   | A playback error is pending; cleared by the next play, source change or `initialize()`   |

`state` is eventually consistent. It reflects the last snapshot received from the native side, not the result of the last call: the future returned by `initialize()` or `play()` completes when the command has been dispatched, not when the state has changed. Read `state` for the initial value and react to `stateStream` afterwards. Before the first snapshot arrives, `state` is an idle state with a volume of 0.5.

### Errors

When `status` is `error`, `state.error` holds a `RadioPlayerError` with a `code` (`RadioPlayerErrorCode`) and a non-empty `message`. There is no automatic retry or reconnect in 4.x. On Android, `play()` prepares the player again after an error; on iOS a failed stream stays in the `error` state until you switch source or call `initialize()` again.

| Code                                                                 | Emitted in 4.x | Meaning                                      |
|----------------------------------------------------------------------|----------------|----------------------------------------------|
| `invalidSource`                                                      | iOS only       | The source URL could not be parsed           |
| `network`                                                            | Android, iOS   | A connectivity problem prevented playback    |
| `unknown`                                                            | Android, iOS   | Any other failure; `message` has the details |
| `httpStatus`, `unsupportedFormat`, `backgroundRestricted`, `timeout` | never          | Reserved, not emitted in 4.x                 |

### What `nowPlaying` contains

`state.nowPlaying` keeps the platform behaviour of `nowPlayingStream`, which still differs between the platforms in 4.x:

- Android: `null` for a moment after a source switch, then the source's `title` (if it has one) and later ICY stream titles as they arrive.
- iOS: `null` after a source switch and until the stream sends an ICY title; the source's `title` is not copied into it.

### Legacy streams

`isPlayingStream`, `nowPlayingStream` and `volumeStream` are superseded by `stateStream` and keep working. They are derived from the same snapshots, are shared between listeners, do not replay the latest value to new listeners, and no longer emit the same value twice in a row. `isPlayingStream` emits when `status == playing` changes on Android, and when `status == playing || status == loading` changes on iOS.

### Calls before `initialize()` or after `dispose()`

`play()`, `pause()`, `playOrPause()`, `nextSource()`, `previousSource()` and `jumpToSourceAtIndex()` called before `initialize()` or after `dispose()` are ignored and logged as a warning on both platforms (`adb logcat -s FlutterRadioPlayer:W` on Android, the unified log on iOS). Call `initialize()` first. It does not need to be awaited before the next call: `initialize(sources); play();` starts playback.

`setVolume()` differs by platform:

- iOS: always applied. Before `initialize()` the volume is remembered and used when the player is created.
- Android: ignored and logged as a warning when there is no player, that is before `initialize()` or after `dispose()`. `initialize()` also sets the volume to 0.5, so a volume set before it does not survive.

`getVolume()` returns 0.5 on Android when there is no player.

## Platform Setup

### Android

Add the following permissions to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

> `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` are already declared by the plugin. `INTERNET` must be declared by the host app.

If your radio streams use plain HTTP (not HTTPS), also opt in to cleartext traffic with `android:usesCleartextTraffic="true"` on your `<application>` tag, or whitelist the streaming hosts with a network security config.

### iOS

Enable **Audio, AirPlay, and Picture in Picture** under your target's **Signing & Capabilities > Background Modes** in Xcode.

If your radio streams use plain HTTP, add the following to your `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## API Reference

### Methods

| Method                    | Description                            |
|---------------------------|----------------------------------------|
| `initialize(sources)`    | Set sources and optionally auto-play   |
| `play()`                 | Resume playback                        |
| `pause()`                | Pause playback                         |
| `playOrPause()`          | Toggle play/pause                      |
| `setVolume(double)`      | Set volume (0.0 to 1.0)               |
| `getVolume()`            | Get current volume                     |
| `nextSource()`           | Skip to next source                    |
| `previousSource()`       | Skip to previous source                |
| `jumpToSourceAtIndex(i)` | Jump to source at index                |
| `dispose()`              | Release player resources               |

### Streams

| Stream / getter    | Type                       | Description                                         |
|--------------------|----------------------------|-----------------------------------------------------|
| `stateStream`      | `Stream<RadioPlayerState>` | State snapshots; new listeners get the latest first |
| `state`            | `RadioPlayerState`         | Latest snapshot (eventually consistent)             |
| `isPlayingStream`  | `Stream<bool>`             | Playback changes (superseded by `stateStream`)      |
| `nowPlayingStream` | `Stream<NowPlayingInfo>`   | Track metadata (superseded by `stateStream`)        |
| `volumeStream`     | `Stream<VolumeInfo>`       | Volume and mute changes (superseded by `stateStream`) |

`FlutterRadioPlayer.instance` is the shared instance.

### Models

```dart
const RadioSource({required String url, String? title, String? artwork});
const NowPlayingInfo({String? title});
const VolumeInfo({required double volume, required bool isMuted});

enum PlaybackStatus { idle, loading, playing, paused, error }
enum RadioPlayerErrorCode { invalidSource, network, httpStatus, unsupportedFormat, backgroundRestricted, timeout, unknown }
const RadioPlayerError({required RadioPlayerErrorCode code, required String message});
const RadioPlayerState({status, currentIndex, currentSource, nowPlaying, volume, error});
```

## Migration from v3

```diff
// Sources
- player.initialize([{"url": "...", "title": "..."}], true);
+ player.initialize([const RadioSource(url: '...', title: '...')], playWhenReady: true);

// Streams
- player.getPlaybackStream()
+ player.isPlayingStream

- player.getNowPlayingStream()
+ player.nowPlayingStream

- player.getDeviceVolumeChangedStream()
+ player.volumeStream

// Methods
- player.prevSource()
+ player.previousSource()

- player.setVolume(0.5)     // unchanged
+ player.setVolume(0.5)

// New
+ await player.dispose();
+ await player.playOrPause();  // now works on iOS too
```

## Example

See the [example app](https://github.com/Sithira/FlutterRadioPlayer/tree/master/example) for a complete implementation.

## Contributing

Contributions are welcome. Please open an issue first to discuss what you would like to change.

## License

[MIT](https://github.com/Sithira/FlutterRadioPlayer/blob/master/LICENSE)
