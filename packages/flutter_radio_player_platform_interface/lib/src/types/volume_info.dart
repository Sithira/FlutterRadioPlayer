class VolumeInfo {
  const VolumeInfo({required this.volume, required this.isMuted});

  final double volume;
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
