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
