class NowPlayingInfo {
  const NowPlayingInfo({this.title});

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
