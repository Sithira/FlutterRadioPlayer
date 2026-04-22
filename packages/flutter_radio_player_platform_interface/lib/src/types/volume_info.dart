/// Represents the current volume state of the player.
class VolumeInfo {
  /// Creates a [VolumeInfo] with the given [volume] level and [isMuted] state.
  const VolumeInfo({required this.volume, required this.isMuted});

  /// The current volume level, between 0.0 (silent) and 1.0 (maximum).
  final double volume;

  /// Whether the player is currently muted.
  final bool isMuted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VolumeInfo &&
          runtimeType == other.runtimeType &&
          volume == other.volume &&
          isMuted == other.isMuted;

  @override
  int get hashCode => Object.hash(volume, isMuted);

  @override
  String toString() => 'VolumeInfo(volume: $volume, isMuted: $isMuted)';
}
