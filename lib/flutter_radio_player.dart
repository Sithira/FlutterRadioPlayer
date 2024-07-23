import 'data/flutter_radio_player_event.dart';
import 'flutter_radio_player_platform_interface.dart';

class FlutterRadioPlayer {
  Future<void> initialize(
      List<Map<String, String>> sources, bool playWhenReady) async {
    FlutterRadioPlayerPlatform.instance.initialize(sources, playWhenReady);
  }

  Future<void> play() {
    return FlutterRadioPlayerPlatform.instance.play();
  }

  Future<void> pause() {
    return FlutterRadioPlayerPlatform.instance.pause();
  }

  Future<void> setVolume(double volume) {
    return FlutterRadioPlayerPlatform.instance.changeVolume(volume);
  }

  Future<double?> getVolume() {
    return FlutterRadioPlayerPlatform.instance.getVolume();
  }

  Future<void> nextSource() {
    return FlutterRadioPlayerPlatform.instance.nextSource();
  }

  Future<void> prevSource() {
    return FlutterRadioPlayerPlatform.instance.previousSource();
  }

  Stream<bool> getPlaybackStream() =>
      FlutterRadioPlayerPlatform.instance.getIsPlayingStream();

  Stream<NowPlayingDataChanged?> getNowPlayingStream() =>
      FlutterRadioPlayerPlatform.instance.getNowPlayingStream();

  Stream<DeviceVolumeDataChanged?> getDeviceVolumeChangedStream() =>
      FlutterRadioPlayerPlatform.instance.getDeviceVolumeChangedStream();
}
