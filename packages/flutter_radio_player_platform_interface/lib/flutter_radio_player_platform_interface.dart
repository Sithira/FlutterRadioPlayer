import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/types/types.dart';

export 'src/types/types.dart';

/// The platform interface for flutter_radio_player.
///
/// Every command returns the state as it is after the native player applied
/// the command. Implementations send the native call synchronously, before
/// their first `await`, so unawaited calls reach the native player in call
/// order. The only error a command reports is a [RangeError] for an index
/// outside the list the native player holds.
abstract class FlutterRadioPlayerPlatform extends PlatformInterface {
  /// Creates a new [FlutterRadioPlayerPlatform].
  FlutterRadioPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterRadioPlayerPlatform? _instance;

  /// The current platform implementation.
  ///
  /// Throws [StateError] if no implementation has been registered.
  static FlutterRadioPlayerPlatform get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'FlutterRadioPlayerPlatform has not been set. '
        'Ensure a platform implementation is registered.',
      );
    }
    return instance;
  }

  /// Registers a platform implementation.
  static set instance(FlutterRadioPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Native state snapshots: the current one once a listener is attached,
  /// then every change. May emit duplicates.
  Stream<RadioPlayerState> get stateStream =>
      throw UnimplementedError('stateStream has not been implemented.');

  /// Replaces the source list; see `FlutterRadioPlayer.setSources`.
  Future<RadioPlayerState> setSources(
    List<RadioSource> sources, {
    int? initialIndex,
    bool autoPlay = false,
  }) => throw UnimplementedError('setSources() has not been implemented.');

  /// Replaces the options of the shared player.
  Future<RadioPlayerState> setOptions(RadioPlayerOptions options) =>
      throw UnimplementedError('setOptions() has not been implemented.');

  /// Plays the current source, or source [index] if given.
  Future<RadioPlayerState> play({int? index}) =>
      throw UnimplementedError('play() has not been implemented.');

  /// Pauses playback.
  Future<RadioPlayerState> pause() =>
      throw UnimplementedError('pause() has not been implemented.');

  /// Pauses if playback is requested, otherwise plays. Decided natively.
  Future<RadioPlayerState> playOrPause() =>
      throw UnimplementedError('playOrPause() has not been implemented.');

  /// Stops playback and closes the stream; keeps sources and settings.
  Future<RadioPlayerState> stop() =>
      throw UnimplementedError('stop() has not been implemented.');

  /// Moves to the next source, keeping the play state.
  Future<RadioPlayerState> next() =>
      throw UnimplementedError('next() has not been implemented.');

  /// Moves to the previous source, keeping the play state.
  Future<RadioPlayerState> previous() =>
      throw UnimplementedError('previous() has not been implemented.');

  /// Sets the player volume, 0.0 to 1.0.
  Future<RadioPlayerState> setVolume(double volume) =>
      throw UnimplementedError('setVolume() has not been implemented.');
}
