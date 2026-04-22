import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/types/types.dart';

export 'src/types/types.dart';

/// The platform interface for flutter_radio_player.
///
/// Platform implementations should extend this class and override all methods.
/// Register the implementation by setting [instance].
abstract class FlutterRadioPlayerPlatform extends PlatformInterface {
  /// Creates a new [FlutterRadioPlayerPlatform].
  FlutterRadioPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRadioPlayerPlatform? _instance;

  /// The current platform implementation.
  ///
  /// Throws [StateError] if no implementation has been registered.
  static FlutterRadioPlayerPlatform get instance {
    if (_instance == null) {
      throw StateError(
        'FlutterRadioPlayerPlatform has not been set. '
        'Ensure a platform implementation is registered.',
      );
    }
    return _instance!;
  }

  /// Registers a platform implementation.
  static set instance(FlutterRadioPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initializes the player with the given [sources].
  ///
  /// Set [playWhenReady] to `true` to begin playback immediately.
  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Starts or resumes playback.
  Future<void> play() {
    throw UnimplementedError('play() has not been implemented.');
  }

  /// Pauses playback.
  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Toggles between play and pause.
  Future<void> playOrPause() {
    throw UnimplementedError('playOrPause() has not been implemented.');
  }

  /// Sets the playback volume to [volume], a value between 0.0 and 1.0.
  Future<void> setVolume(double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  /// Returns the current playback volume.
  Future<double> getVolume() {
    throw UnimplementedError('getVolume() has not been implemented.');
  }

  /// Advances to the next source in the playlist.
  Future<void> nextSource() {
    throw UnimplementedError('nextSource() has not been implemented.');
  }

  /// Returns to the previous source in the playlist.
  Future<void> previousSource() {
    throw UnimplementedError('previousSource() has not been implemented.');
  }

  /// Jumps to the source at the given [index].
  Future<void> jumpToSourceAtIndex(int index) {
    throw UnimplementedError('jumpToSourceAtIndex() has not been implemented.');
  }

  /// Releases all resources held by the player.
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// A stream that emits `true` when playing, `false` when paused.
  Stream<bool> get isPlayingStream {
    throw UnimplementedError('isPlayingStream has not been implemented.');
  }

  /// A stream of [NowPlayingInfo] with current track metadata.
  Stream<NowPlayingInfo> get nowPlayingStream {
    throw UnimplementedError('nowPlayingStream has not been implemented.');
  }

  /// A stream of [VolumeInfo] when the volume changes.
  Stream<VolumeInfo> get volumeStream {
    throw UnimplementedError('volumeStream has not been implemented.');
  }
}
