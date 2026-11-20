import 'package:flutter/foundation.dart';

import 'now_playing_info.dart';
import 'playback_status.dart';
import 'radio_player_error.dart';
import 'radio_source.dart';
import 'unset.dart';

/// A snapshot of the shared player.
///
/// Invariants kept by the native player (not enforced here):
/// - [status] is [PlaybackStatus.idle] exactly when [sources] is empty, and
///   then [currentIndex] is `null`;
/// - [PlaybackStatus.error] implies [error] is set;
/// - [error] is set only while [status] is [PlaybackStatus.error] or
///   [PlaybackStatus.loading] (reconnecting).
@immutable
class RadioPlayerState {
  /// Creates a [RadioPlayerState]. The defaults describe a player with no
  /// sources.
  const RadioPlayerState({
    this.status = PlaybackStatus.idle,
    this.sources = const [],
    this.currentIndex,
    this.nowPlaying,
    this.volume = 1.0,
    this.error,
  });

  /// The playback status.
  final PlaybackStatus status;

  /// The source list the native player holds, as set by any engine.
  final List<RadioSource> sources;

  /// Index of the current source in [sources], or `null` when there are none.
  final int? currentIndex;

  /// The track on air, or `null` until the stream sends a title for the
  /// current source.
  final NowPlayingInfo? nowPlaying;

  /// Player volume from 0.0 to 1.0.
  final double volume;

  /// The current source's failure, while retrying or after giving up.
  final RadioPlayerError? error;

  /// `sources[currentIndex]`, or `null` when there is no current source.
  RadioSource? get currentSource {
    final index = currentIndex;
    if (index == null || index < 0 || index >= sources.length) return null;
    return sources[index];
  }

  /// Whether playback is requested: [PlaybackStatus.playing] or
  /// [PlaybackStatus.loading]. Use it for a play/pause button. For "audible
  /// right now", compare [status] with [PlaybackStatus.playing].
  bool get isPlaying =>
      status == PlaybackStatus.playing || status == PlaybackStatus.loading;

  /// Whether playback is requested but not audible yet.
  bool get isLoading => status == PlaybackStatus.loading;

  /// Whether the stream failed and the player is retrying; [error] says why.
  bool get isReconnecting => status == PlaybackStatus.loading && error != null;

  /// Returns a copy with the given fields replaced. Pass `null` to clear
  /// [currentIndex], [nowPlaying] or [error].
  RadioPlayerState copyWith({
    PlaybackStatus? status,
    List<RadioSource>? sources,
    Object? currentIndex = unset,
    Object? nowPlaying = unset,
    double? volume,
    Object? error = unset,
  }) {
    return RadioPlayerState(
      status: status ?? this.status,
      sources: sources ?? this.sources,
      currentIndex: currentIndex == unset
          ? this.currentIndex
          : currentIndex as int?,
      nowPlaying: nowPlaying == unset
          ? this.nowPlaying
          : nowPlaying as NowPlayingInfo?,
      volume: volume ?? this.volume,
      error: error == unset ? this.error : error as RadioPlayerError?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioPlayerState &&
          status == other.status &&
          listEquals(sources, other.sources) &&
          currentIndex == other.currentIndex &&
          nowPlaying == other.nowPlaying &&
          volume == other.volume &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(sources),
    currentIndex,
    nowPlaying,
    volume,
    error,
  );

  @override
  String toString() =>
      'RadioPlayerState(status: ${status.name}, '
      'currentIndex: $currentIndex, sources: $sources, '
      'nowPlaying: $nowPlaying, volume: $volume, error: $error)';
}
