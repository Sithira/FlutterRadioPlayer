import 'package:flutter/foundation.dart';

import 'unset.dart';

/// A radio stream.
@immutable
class RadioSource {
  /// Creates a source for the stream at [url].
  ///
  /// [id] defaults to [url]. The player uses it to recognise the current
  /// source across `setSources` calls; duplicate ids are allowed and the first
  /// match wins.
  const RadioSource({
    required this.url,
    String? id,
    this.title,
    this.artwork,
    this.headers = const {},
  }) : id = id ?? url;

  /// Identifies this source across `setSources` calls. Defaults to [url].
  final String id;

  /// The stream URL. Not validated in Dart: a URL that is not an absolute
  /// `http` or `https` URL fails with `invalidSource` when it is played.
  final String url;

  /// Display title, shown on the lock screen and in the notification.
  final String? title;

  /// Artwork as an `http(s)` URL or a Flutter asset path.
  final String? artwork;

  /// HTTP headers sent with the stream request.
  final Map<String, String> headers;

  /// Returns a copy with the given fields replaced. Pass `null` to clear
  /// [title] or [artwork].
  RadioSource copyWith({
    String? id,
    String? url,
    Object? title = unset,
    Object? artwork = unset,
    Map<String, String>? headers,
  }) {
    return RadioSource(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title == unset ? this.title : title as String?,
      artwork: artwork == unset ? this.artwork : artwork as String?,
      headers: headers ?? this.headers,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadioSource &&
          id == other.id &&
          url == other.url &&
          title == other.title &&
          artwork == other.artwork &&
          mapEquals(headers, other.headers);

  @override
  int get hashCode => Object.hash(
    id,
    url,
    title,
    artwork,
    Object.hashAllUnordered(
      headers.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'RadioSource(id: $id, url: $url, title: $title, '
      'artwork: $artwork, headers: ${headers.keys.toList()})';
}
