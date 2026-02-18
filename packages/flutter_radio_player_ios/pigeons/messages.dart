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
  void initialize(List<RadioSourceMessage> sources, bool playWhenReady);
  void play();
  void pause();
  void playOrPause();
  void setVolume(double volume);
  double getVolume();
  void nextSource();
  void previousSource();
  void jumpToSourceAtIndex(int index);
  void dispose();
}

@EventChannelApi()
abstract class RadioPlayerEventApi {
  bool onPlaybackStateChanged();
  NowPlayingInfoMessage onNowPlayingChanged();
  VolumeInfoMessage onVolumeChanged();
}
