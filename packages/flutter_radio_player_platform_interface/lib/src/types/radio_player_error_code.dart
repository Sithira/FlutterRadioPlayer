/// The category of a [RadioPlayerError].
///
/// [network], [timeout], [unknown] and [httpStatus] 5xx are retried (see
/// `ReconnectPolicy`); the others set the status to `error` at once.
enum RadioPlayerErrorCode {
  /// The source URL is not an absolute `http` or `https` URL.
  invalidSource,

  /// A network connectivity problem prevented playback.
  network,

  /// The server answered with an HTTP error status.
  httpStatus,

  /// The stream format is not supported.
  unsupportedFormat,

  /// The system did not allow playback to start in the background.
  backgroundRestricted,

  /// Connecting or reading the stream timed out.
  timeout,

  /// The cause could not be determined.
  unknown,
}
