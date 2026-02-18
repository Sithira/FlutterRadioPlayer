import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/types/types.dart';

export 'src/types/types.dart';

abstract class FlutterRadioPlayerPlatform extends PlatformInterface {
  FlutterRadioPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRadioPlayerPlatform? _instance;

  static FlutterRadioPlayerPlatform get instance {
    if (_instance == null) {
      throw StateError(
        'FlutterRadioPlayerPlatform has not been set. '
        'Ensure a platform implementation is registered.',
      );
    }
    return _instance!;
  }

  static set instance(FlutterRadioPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> play() {
    throw UnimplementedError('play() has not been implemented.');
  }

  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> playOrPause() {
    throw UnimplementedError('playOrPause() has not been implemented.');
  }

  Future<void> setVolume(double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  Future<double> getVolume() {
    throw UnimplementedError('getVolume() has not been implemented.');
  }

  Future<void> nextSource() {
    throw UnimplementedError('nextSource() has not been implemented.');
  }

  Future<void> previousSource() {
    throw UnimplementedError('previousSource() has not been implemented.');
  }

  Future<void> jumpToSourceAtIndex(int index) {
    throw UnimplementedError('jumpToSourceAtIndex() has not been implemented.');
  }

  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  Stream<bool> get isPlayingStream {
    throw UnimplementedError('isPlayingStream has not been implemented.');
  }

  Stream<NowPlayingInfo> get nowPlayingStream {
    throw UnimplementedError('nowPlayingStream has not been implemented.');
  }

  Stream<VolumeInfo> get volumeStream {
    throw UnimplementedError('volumeStream has not been implemented.');
  }
}
