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
  late String url;
  late String? title;
  late String? artwork;
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
  late int? currentIndex;
  late String? nowPlayingTitle;
  late double volume;
  late RadioPlayerErrorMessage? error;
}

@HostApi()
abstract class RadioPlayerHostApi {
  @asyncCallback
  void initialize(List<RadioSourceMessage> sources, bool playWhenReady);
  @asyncCallback
  void play();
  @asyncCallback
  void pause();
  @asyncCallback
  void playOrPause();
  @asyncCallback
  void setVolume(double volume);
  @asyncCallback
  double getVolume();
  @asyncCallback
  void nextSource();
  @asyncCallback
  void previousSource();
  @asyncCallback
  void jumpToSourceAtIndex(int index);
  @asyncCallback
  void dispose();
  @asyncCallback
  RadioPlayerStateMessage getState();
}

@EventChannelApi()
abstract class RadioPlayerEventApi {
  RadioPlayerStateMessage onStateChanged();
}
