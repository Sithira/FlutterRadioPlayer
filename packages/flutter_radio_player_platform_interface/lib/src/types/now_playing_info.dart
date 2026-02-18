/// Information about the currently playing track, typically from ICY metadata.
class NowPlayingInfo {
  /// Creates a [NowPlayingInfo] with an optional [title].
  const NowPlayingInfo({this.title});

  /// The title of the currently playing track, or `null` if unavailable.
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NowPlayingInfo &&
          runtimeType == other.runtimeType &&
          title == other.title;

  @override
  int get hashCode => title.hashCode;

  @override
  String toString() => 'NowPlayingInfo(title: $title)';
}
