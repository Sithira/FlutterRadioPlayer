/// Represents a radio stream source with a URL and optional metadata.
class RadioSource {
  /// Creates a [RadioSource] with the given stream [url].
  ///
  /// Optionally provide a [title] for display and an [artwork] URL for
  /// lock-screen / notification artwork.
  const RadioSource({required this.url, this.title, this.artwork});

  /// The URL of the radio stream.
  final String url;

  /// An optional display title for this source.
  final String? title;

  /// An optional artwork URL shown on lock-screen and notification controls.
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
