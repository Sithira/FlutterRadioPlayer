import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  kotlinOut:
      'android/src/main/kotlin/me/sithiramunasinghe/flutter/flutter_radio_player/Messages.g.kt',
  kotlinOptions: KotlinOptions(
    package: 'me.sithiramunasinghe.flutter.flutter_radio_player',
  ),
))
class RadioSourceMessage {
  late String id;
  late String url;
  late String? title;
  late String? artwork;
  late Map<String, String> headers;
}

enum PlaybackStatusMessage { idle, loading, playing, paused, error }

enum RadioPlayerErrorCodeMessage {
  invalidSource,
  network,
  httpStatus,
  unsupportedFormat,
  backgroundRestricted,
  timeout,
  unknown,
}

class RadioPlayerErrorMessage {
  late RadioPlayerErrorCodeMessage code;
  late String message;
}

class RadioPlayerStateMessage {
  late PlaybackStatusMessage status;
  late List<RadioSourceMessage> sources;
  late int? currentIndex;
  late String? nowPlayingTitle;
  late double volume;
  late RadioPlayerErrorMessage? error;
}

class RadioPlayerOptionsMessage {
  late bool wrapAround;
  late int reconnectGiveUpAfterMillis;
  late bool androidStopOnTaskRemoved;
  late String? androidNotificationIcon;
}

@HostApi()
abstract class RadioPlayerHostApi {
  @asyncCallback
  RadioPlayerStateMessage setSources(
    List<RadioSourceMessage> sources,
    int? initialIndex,
    bool autoPlay,
  );
  @asyncCallback
  RadioPlayerStateMessage setOptions(RadioPlayerOptionsMessage options);
  @asyncCallback
  RadioPlayerStateMessage play(int? index);
  @asyncCallback
  RadioPlayerStateMessage pause();
  @asyncCallback
  RadioPlayerStateMessage playOrPause();
  @asyncCallback
  RadioPlayerStateMessage stop();
  @asyncCallback
  RadioPlayerStateMessage next();
  @asyncCallback
  RadioPlayerStateMessage previous();
  @asyncCallback
  RadioPlayerStateMessage setVolume(double volume);
}

@EventChannelApi()
abstract class RadioPlayerEventApi {
  RadioPlayerStateMessage onStateChanged();
}
