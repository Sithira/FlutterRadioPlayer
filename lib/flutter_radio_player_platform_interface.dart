import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'data/flutter_radio_player_event.dart';
import 'flutter_radio_player_method_channel.dart';

abstract class FlutterRadioPlayerPlatform extends PlatformInterface {
  /// Constructs a FlutterRadioPlayerPlatform.
  FlutterRadioPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRadioPlayerPlatform _instance =
      MethodChannelFlutterRadioPlayer();

  /// The default instance of [FlutterRadioPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterRadioPlayer].
  static FlutterRadioPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterRadioPlayerPlatform] when
  /// they register themselves.
  static set instance(FlutterRadioPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize flutter radio player
  Future<void> initialize(
      List<Map<String, String>> sources, bool playWhenReady) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Play the media source
  Future<void> play() {
    throw UnimplementedError('play() has not been implemented.');
  }

  /// Pause the media source
  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Either play or pause depending on the play state
  Future<void> playOrPause() {
    throw UnimplementedError('playOrPause() has not been implemented.');
  }

  /// Change the player volume
  Future<void> changeVolume(double volume);

  /// Change the next source in the sources index
  Future<void> nextSource();

  /// Change the previous source in the sources index
  Future<void> previousSource();

  /// Jump to source at a index
  Future<void> jumpToSourceIndex(int index);

  /// Get the current volume of the player. Defaults to 0.5 (low: 0, max: 1)
  Future<double?> getVolume();

  /// Playback stream
  Stream<bool> getIsPlayingStream();

  /// Now playing stream of icy / meta info
  Stream<NowPlayingDataChanged?> getNowPlayingStream();

  /// Stream of player volume changes
  Stream<DeviceVolumeDataChanged?> getDeviceVolumeChangedStream();
}
