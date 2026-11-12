/// Flutter Radio Player library for streaming online radio with background
/// playback support on Android and iOS.
library flutter_radio_player;

export 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart'
    show
        RadioSource,
        NowPlayingInfo,
        VolumeInfo,
        RadioPlayerState,
        PlaybackStatus,
        RadioPlayerError,
        RadioPlayerErrorCode;

import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

/// A Flutter plugin for playing online radio streams with background audio,
/// lock-screen controls, and ICY metadata support.
///
/// ```dart
/// final player = FlutterRadioPlayer();
/// await player.initialize([
///   RadioSource(url: 'https://example.com/stream', title: 'My Station'),
/// ], playWhenReady: true);
/// ```
class FlutterRadioPlayer {
  /// A shared instance for convenience.
  ///
  /// All instances drive the same native player, so this is not a way to
  /// isolate players from each other.
  static final FlutterRadioPlayer instance = FlutterRadioPlayer();

  FlutterRadioPlayerPlatform get _platform =>
      FlutterRadioPlayerPlatform.instance;

  /// Initializes the player with the given [sources].
  ///
  /// Set [playWhenReady] to `true` to begin playback immediately after
  /// initialization. Defaults to `false`.
  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) {
    return _platform.initialize(sources, playWhenReady: playWhenReady);
  }

  /// Starts or resumes playback of the current source.
  Future<void> play() => _platform.play();

  /// Pauses playback.
  Future<void> pause() => _platform.pause();

  /// Toggles between play and pause.
  Future<void> playOrPause() => _platform.playOrPause();

  /// Sets the playback volume to [volume], a value between 0.0 and 1.0.
  Future<void> setVolume(double volume) => _platform.setVolume(volume);

  /// Returns the current playback volume (0.0 to 1.0).
  Future<double> getVolume() => _platform.getVolume();

  /// Advances to the next source in the playlist.
  Future<void> nextSource() => _platform.nextSource();

  /// Returns to the previous source in the playlist.
  Future<void> previousSource() => _platform.previousSource();

  /// Jumps to the source at the given [index] in the playlist.
  Future<void> jumpToSourceAtIndex(int index) =>
      _platform.jumpToSourceAtIndex(index);

  /// Releases all resources held by the player.
  ///
  /// Call this when the player is no longer needed.
  Future<void> dispose() => _platform.dispose();

  /// A stream that emits `true` when playback starts and `false` when it stops.
  Stream<bool> get isPlayingStream => _platform.isPlayingStream;

  /// A stream of [NowPlayingInfo] updates, including ICY metadata titles.
  Stream<NowPlayingInfo> get nowPlayingStream => _platform.nowPlayingStream;

  /// A stream of [VolumeInfo] updates when the volume changes.
  Stream<VolumeInfo> get volumeStream => _platform.volumeStream;

  /// The latest snapshot of the player state.
  ///
  /// Before any snapshot has arrived this is an idle state. The value is
  /// eventually consistent: it reflects the most recent snapshot received from
  /// the platform, not the result of the last call. Use [stateStream] to react
  /// to changes.
  RadioPlayerState get state => _platform.state;

  /// A stream of [RadioPlayerState] snapshots.
  ///
  /// Every new listener first receives the latest snapshot, if one has arrived,
  /// followed by live updates.
  Stream<RadioPlayerState> get stateStream => _platform.stateStream;
}
