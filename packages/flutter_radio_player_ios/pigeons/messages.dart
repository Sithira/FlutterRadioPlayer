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

class NowPlayingInfoMessage {
  late String? title;
}

class VolumeInfoMessage {
  late double volume;
  late bool isMuted;
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
}

@EventChannelApi()
abstract class RadioPlayerEventApi {
  bool onPlaybackStateChanged();
  NowPlayingInfoMessage onNowPlayingChanged();
  VolumeInfoMessage onVolumeChanged();
}
