/// The high-level playback status of the player.
enum PlaybackStatus {
  /// No sources are loaded, or the player has been disposed.
  idle,

  /// Playback has been requested but is not yet audible.
  loading,

  /// Audio is playing.
  playing,

  /// Sources are loaded and playback has not been requested, or is suppressed.
  paused,

  /// A playback error is pending.
  ///
  /// Cleared by the next play, source change or initialize.
  error,
}
