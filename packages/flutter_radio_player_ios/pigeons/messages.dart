import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  swiftOut:
      'ios/flutter_radio_player_ios/Sources/flutter_radio_player_ios/Messages.g.swift',
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
  @async
  void initialize(List<RadioSourceMessage> sources, bool playWhenReady);
  @async
  void play();
  @async
  void pause();
  @async
  void playOrPause();
  @async
  void setVolume(double volume);
  @async
  double getVolume();
  @async
  void nextSource();
  @async
  void previousSource();
  @async
  void jumpToSourceAtIndex(int index);
  @async
  void dispose();
  @async
  RadioPlayerStateMessage getState();
}

@EventChannelApi()
abstract class RadioPlayerEventApi {
  RadioPlayerStateMessage onStateChanged();
}
