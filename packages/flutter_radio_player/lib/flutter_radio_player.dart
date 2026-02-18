export 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart'
    show RadioSource, NowPlayingInfo, VolumeInfo;

import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

class FlutterRadioPlayer {
  FlutterRadioPlayerPlatform get _platform =>
      FlutterRadioPlayerPlatform.instance;

  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) {
    return _platform.initialize(sources, playWhenReady: playWhenReady);
  }

  Future<void> play() => _platform.play();

  Future<void> pause() => _platform.pause();

  Future<void> playOrPause() => _platform.playOrPause();

  Future<void> setVolume(double volume) => _platform.setVolume(volume);

  Future<double> getVolume() => _platform.getVolume();

  Future<void> nextSource() => _platform.nextSource();

  Future<void> previousSource() => _platform.previousSource();

  Future<void> jumpToSourceAtIndex(int index) =>
      _platform.jumpToSourceAtIndex(index);

  Future<void> dispose() => _platform.dispose();

  Stream<bool> get isPlayingStream => _platform.isPlayingStream;

  Stream<NowPlayingInfo> get nowPlayingStream => _platform.nowPlayingStream;

  Stream<VolumeInfo> get volumeStream => _platform.volumeStream;
}
