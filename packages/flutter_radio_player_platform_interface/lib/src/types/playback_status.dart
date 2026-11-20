/// The high-level playback status of the player.
enum PlaybackStatus {
  /// No sources.
  idle,

  /// Playback is requested but not audible yet: connecting, buffering,
  /// stalled or reconnecting.
  loading,

  /// Audio is playing.
  playing,

  /// Sources are set and playback is not requested: never started, paused,
  /// stopped, or held back by the system.
  paused,

  /// Playback failed and the player is not retrying. `play()` tries again.
  error,
}
