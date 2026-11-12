/// The category of a [RadioPlayerError].
///
/// In 4.x iOS emits [invalidSource], [network] and [unknown], and Android emits
/// [network] and [unknown]. The other values are reserved and may never be
/// emitted.
enum RadioPlayerErrorCode {
  /// The source URL is invalid.
  invalidSource,

  /// A network connectivity problem prevented playback.
  network,

  /// The server answered with an unusable HTTP status. Reserved.
  httpStatus,

  /// The stream format is not supported. Reserved.
  unsupportedFormat,

  /// The system restricted background playback. Reserved.
  backgroundRestricted,

  /// The operation timed out. Reserved.
  timeout,

  /// The cause could not be determined.
  unknown,
}
