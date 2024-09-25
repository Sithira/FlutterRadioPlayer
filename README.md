![logo](flutter_radio_player_logo.png)

# Flutter Radio Player

![Pub Version](https://img.shields.io/pub/v/flutter_radio_player?style=plastic)
![Pub Likes](https://img.shields.io/pub/likes/flutter_radio_player)
![Pub Points](https://img.shields.io/pub/points/flutter_radio_player)
![Pub Popularity](https://img.shields.io/pub/popularity/flutter_radio_player)

**Flutter Radio Player** is the go-to plugin for playing a single streaming URL effortlessly. With support for background music playback right out of the box, it offers seamless integration with platform-native media controls. Whether it's lock screen media controls or deeper integrations like watchOS, CarPlay, WearOS, or Android Auto, Flutter Radio Player handles it all with no extra configuration needed.

## Features

- **Background Playback**: Plays audio in the background without any configuration.
- **Watch Integration**: Seamlessly integrates with WatchOS and WearOS for native watch control.
- **Automotive Systems**: Supports infotainment systems like Apple CarPlay and Android Auto.
- **Reactive by Default**: Automatically reacts to stream changes.
- **ICY/Metadata Extraction**: Extracts stream metadata if available.

## Getting Started

### 1. Install the Player

```bash
flutter pub add flutter_radio_player
```

### 2. Import the Library

```dart
import 'package:flutter_radio_player/flutter_radio_player.dart';
```

### 3. Configure the Player

```dart
final _flutterRadioPlayerPlugin = FlutterRadioPlayer(); // Create an instance of the player
_flutterRadioPlayerPlugin.initialize(
  [
    {"url": "https://s2-webradio.antenne.de/chillout?icy=https"},
    {
      "title": "SunFM - Sri Lanka",
      "artwork": "images/sample-cover.jpg", // Image needs to be bundled with the app
      "url": "https://radio.lotustechnologieslk.net:2020/stream/sunfmgarden?icy=https",
    },
    {"url": "http://stream.riverradio.com:8000/wcvofm.aac"}
  ],
  true, // Auto play on load
);
```

Once configured, your player is ready to stream music.

### Manipulating the Player

You can control the player using the following methods:

| Method                 | Action                                                     |
|------------------------|------------------------------------------------------------|
| `play()`               | Plays the audio from the current source                    |
| `pause()`              | Pauses the audio                                           |
| `playOrPause()`        | Toggles play/pause                                         |
| `changeVolume()`       | Adjusts the volume                                         |
| `getVolume()`          | Retrieves the current volume                               |
| `nextSource()`         | Skips to the next source in the list (if available)        |
| `previousSource()`     | Goes to the previous source                                |
| `jumpToSourceIndex()`  | Jumps to a specific index in the sources list              |

### Available Streams

You can also listen to various streams:

| Stream                           | Returns                             | Description                                          |
|-----------------------------------|-------------------------------------|------------------------------------------------------|
| `getIsPlayingStream()`            | `Stream<bool>`                      | Emits playback status                                |
| `getNowPlayingStream()`           | `Stream<NowPlayingDataChanged>`      | Emits metadata such as track name                    |
| `getDeviceVolumeChangedStream()`  | `Stream<double>`                    | Emits device audio level updates                     |

## Platform Configuration

### iOS

To enable background playback, configure background capabilities in Xcode as shown below:

![Xcode Configuration](enabling-xcode-bg-service.png)

### Android

For Android, ensure the following permissions are added to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
```

> These permissions are already included in the library.

**Check out the [Flutter Radio Player Example](/example)** to see how to implement action methods and streams in your player.

## Support the Plugin

If you find this plugin useful, show your support by:

- Giving it a ⭐️ on [GitHub](https://github.com/Sithira/FlutterRadioPlayer)
- Leaving a like on Pub
- Showing some ♥️ and buying me a coffee via USDT-TR20 at this address: `TNuTkL1ZJGu2xntmtzHzSiH5YdVqUeAujr`

**Enjoy the plugin!**  
Sithira ✌️