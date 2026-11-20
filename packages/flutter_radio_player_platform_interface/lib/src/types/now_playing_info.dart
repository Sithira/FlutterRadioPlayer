import 'package:flutter/foundation.dart';

/// The track currently on air, from the stream's ICY `StreamTitle`.
@immutable
class NowPlayingInfo {
  /// Creates a [NowPlayingInfo] with the raw stream [title].
  const NowPlayingInfo({required this.title});

  /// The raw `StreamTitle` as sent by the station.
  final String title;

  /// The part of [title] before the first `" - "`, trimmed. `null` if there
  /// is no separator or either side is empty. Best effort: stations format the
  /// title as they like.
  String? get artist => _split()?.$1;

  /// The part of [title] after the first `" - "`, trimmed. `null` if there is
  /// no separator or either side is empty.
  String? get song => _split()?.$2;

  (String, String)? _split() {
    final separator = title.indexOf(' - ');
    if (separator < 0) return null;
    final artist = title.substring(0, separator).trim();
    final song = title.substring(separator + 3).trim();
    if (artist.isEmpty || song.isEmpty) return null;
    return (artist, song);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NowPlayingInfo && title == other.title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() => 'NowPlayingInfo(title: $title)';
}
