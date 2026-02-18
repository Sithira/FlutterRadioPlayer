import 'package:flutter/foundation.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

import 'src/messages.g.dart';

class FlutterRadioPlayerIos extends FlutterRadioPlayerPlatform {
  final RadioPlayerHostApi _hostApi = RadioPlayerHostApi();

  static void registerWith() {
    FlutterRadioPlayerPlatform.instance = FlutterRadioPlayerIos();
  }

  @override
  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) {
    return _hostApi.initialize(
      sources.map(_toMessage).toList(),
      playWhenReady,
    );
  }

  @override
  Future<void> play() => _hostApi.play();

  @override
  Future<void> pause() => _hostApi.pause();

  @override
  Future<void> playOrPause() => _hostApi.playOrPause();

  @override
  Future<void> setVolume(double volume) => _hostApi.setVolume(volume);

  @override
  Future<double> getVolume() => _hostApi.getVolume();

  @override
  Future<void> nextSource() => _hostApi.nextSource();

  @override
  Future<void> previousSource() => _hostApi.previousSource();

  @override
  Future<void> jumpToSourceAtIndex(int index) =>
      _hostApi.jumpToSourceAtIndex(index);

  @override
  Future<void> dispose() => _hostApi.dispose();

  @override
  @visibleForTesting
  Stream<bool> get isPlayingStream => onPlaybackStateChanged();

  @override
  Stream<NowPlayingInfo> get nowPlayingStream =>
      onNowPlayingChanged().map((msg) => NowPlayingInfo(title: msg.title));

  @override
  Stream<VolumeInfo> get volumeStream => onVolumeChanged()
      .map((msg) => VolumeInfo(volume: msg.volume, isMuted: msg.isMuted));

  static RadioSourceMessage _toMessage(RadioSource source) {
    return RadioSourceMessage(
      url: source.url,
      title: source.title,
      artwork: source.artwork,
    );
  }
}
