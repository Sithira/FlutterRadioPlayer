![logo](flutter_radio_player_logo.png)

# flutter_radio_player

Online Radio Player for Flutter

![Pub Version](https://img.shields.io/pub/v/flutter_radio_player?style=plastic)
![Pub Likes](https://img.shields.io/pub/likes/flutter_radio_player)
![Pub Points](https://img.shields.io/pub/points/flutter_radio_player)
![Pub Popularity](https://img.shields.io/pub/popularity/flutter_radio_player)

# 

Flutter radio plugin handles a single streaming media preciously. This plugin was developed with maximum usage in mind.
Flutter Radio player enables Streaming audio content on both Android and iOS natively, as an added feature this plugin supports
background music play as well. This plugin also integrate deeply with both core media capabilities such as MediaSession on Android and
RemoteControl capabilities (Control Center) on iOS. This plugin also support controlling the player via both wearOS and WatchOS.

## Features

* Supports both android and ios
* Supports background music playing
* Integrates well with watchOS and WearOS.
* Handles network interruptions.
* Reactive
* Developer friendly (Logs are placed though out the codebase, so it's easy to trace a bug)

## Reactivity ?

Unlike any other Music Playing plugin Flutter Radio Player is very reactive. It communicates with the native layer using Event and Streams, this
making the plugin very reactive to both Application (Flutter) side and the native side.

### Plugin events

This plugin utilises Android LocalBroadcaster and iOS Notification center for pushing out events. Names of the events are listed below.

* `flutter_radio_playing`
* `flutter_radio_paused`
* `flutter_radio_stopped`
* `flutter_radio_error`
* `flutter_radio_loading`

## Getting Started

1. Add this to your package's pubspec.yaml file

```yaml
dependencies:
  flutter_radio_player: ^2.X.X
```

2. Install it

```shell script
$ flutter pub get
```

3. Import it

```dart
import 'package:flutter_radio_player/flutter_radio_player.dart';
```

4. Configure it
   Creat a new instance of the player. An `FlutterRadioPlayer` instance can play a
   single audio stream at a time. To create it, simply call the constructor.
   However, DO NOT make multiple instances of the service as FRP is using a `FOREGROUND SERVICE` to keep itself
   live when you minimize the application in `Android`.

````dart
FlutterRadioPlayer _flutterRadioPlayer = FlutterRadioPlayer();
````

When you have an FRP instance you may simply call the `init` method to invoke the platform specific player preparation.

```dart
_flutterRadioPlayer.initPlayer();
```

When you have successfully initialized the player, then you can add media sources for the player to play.

```dart
  final FRPSource frpSource = FRPSource(
    mediaSources: <MediaSources>[
      MediaSources(
        url: "http://icecast.sithira.net:8052/stream", // dummy url
        description: "Stream with ICY",
        isPrimary: true,
        title: "Z Fun hundred",
        isAac: true
      ),
      MediaSources(
        url: "http://my-url:1025/stream;", // dummy url
        description: "Hiru FM Sri Lanka",
        isPrimary: false,
        title: "HiruFM",
        isAac: false
      ),
    ],
  );
```

As you can see, you have a couple of options for media source as well. One being available to use as the primary media-source.
if you set a source as **primary** as it will be used to as the default source. But keep in mind that you cant have multiple **primary** data sources.

Once you have the media sources ready you might send the source list to player by calling

```dart
_flutterRadioPlayer.addMediaSources(frpSource);
```

In previous versions of FRP, you couldn't keep more than one stream. but with v2, you are able handle more source but only 1 stream will be active at once. Futhermore you will able to add the sources dynamically by calling

```dart
_flutterRadioPlayer.addMediaSource(myDynamicSource);

```

Besides above-mentioned method, below are the methods that FRP exposes.

* ```stop()``` - Will stop all the streaming audio streams and detaches itself from `FOREGROUND SERVICE`. You need to reinitialize to  use the plugin again,

```dart
_flutterRadioPlayer.stop()
```

* ```start()``` - Will start the audio stream using the initialized object.

```dart
_flutterRadioPlayer.start()
```

* ```pause()``` - Will pause the audio stream using the initialized object.

```dart
_flutterRadioPlayer.pause()
```

* ```next()``` - Will advance the player's active media-source to next if you have multiple sources setup.

```dart
_flutterRadioPlayer.next()
```

* ```previous()``` - Will fallback the player's active media-source to previous if you have multiple sources setup.

```dart
_flutterRadioPlayer.previous()
```

* ```setVolume(volumne)``` - Will set the player volume. Keep in mind that the plugin will adjust along with the system volume as well to give the best experience.

```dart
_flutterRadioPlayer.setVolume(0.25)
```

* If you are planing to keep track of the media-sources by your-self, you can use below.

```dart
_flutterRadioPlayer.seekToMediaSource(position,  playWhenReady);
```

## Did someone say ID3/Icy-Header info 🥳?

Yes, we have support for Icy and Shoutcast ID3 data pulling as well if your stream supports it. Plugin push the contents through when you stream details change along with the
track change. We have done our testing for this, but it's mainly over icecast only.

## iOS and Android Support

If the plugin is failing to initiate, kindly make sure your permission for background processes are given for your application

For your Android application you might want to add permissions in `AndroidManifest.xml`. This is already added for in the library level.

```xml
    <!--  Permissions for the plugin  -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.INTERNET" />

    <!--  Services for the plugin  -->
    <application android:usesCleartextTraffic="true">
        <service android:name=".core.StreamingCore"/>
    </application>
```

For your iOS application you need to enable it like this

![xcode image](enabling-xcode-bg-service.png)

Now that's not all. This plugin handles almost everything for you when it comes to `playing a single stream of audio`. From Player meta details to network interruptions,
FRP handles it all with a sweat. Please refer the example to get an idea about what FRP can do.

## Support

Please hit a like to plugin on pub if you used it and love it. put a ⭐️ my GitHub [repo](https://github.com/Sithira/FlutterRadioPlayer) and show me some ♥️ so i can keep working on this.

### Found a bug ?

Please feel free to throw in a pull request. Any support is warmly welcome.
