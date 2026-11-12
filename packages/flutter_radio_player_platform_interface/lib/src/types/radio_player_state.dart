import 'now_playing_info.dart';
import 'playback_status.dart';
import 'radio_player_error.dart';
import 'radio_source.dart';

/// A snapshot of the player state.
class RadioPlayerState {
  /// Creates a [RadioPlayerState].
  ///
  /// The defaults describe a player with nothing loaded.
  const RadioPlayerState({
    this.status = PlaybackStatus.idle,
    this.currentIndex,
    this.currentSource,
    this.nowPlaying,
    this.volume = 0.5,
    this.error,
  });

  /// The current playback status.
  final PlaybackStatus status;

  /// The index of the current source, or `null` if no source is loaded.
  final int? currentIndex;

  /// The current source, or `null` if no source is loaded.
  final RadioSource? currentSource;

  /// The current track metadata, or `null` if none is available.
  final NowPlayingInfo? nowPlaying;

  /// The playback volume, between 0.0 (silent) and 1.0 (maximum).
  final double volume;

  /// The pending playback error, or `null` if there is none.
  final RadioPlayerError? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioPlayerState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          currentIndex == other.currentIndex &&
          currentSource == other.currentSource &&
          nowPlaying == other.nowPlaying &&
          volume == other.volume &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
        status,
        currentIndex,
        currentSource,
        nowPlaying,
        volume,
        error,
      );

  @override
  String toString() =>
      'RadioPlayerState(status: $status, currentIndex: $currentIndex, '
      'currentSource: $currentSource, nowPlaying: $nowPlaying, '
      'volume: $volume, error: $error)';
}
