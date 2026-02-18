class RadioSource {
  const RadioSource({required this.url, this.title, this.artwork});

  final String url;
  final String? title;
  final String? artwork;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioSource &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          title == other.title &&
          artwork == other.artwork;

  @override
  int get hashCode => Object.hash(url, title, artwork);

  @override
  String toString() =>
      'RadioSource(url: $url, title: $title, artwork: $artwork)';
}
