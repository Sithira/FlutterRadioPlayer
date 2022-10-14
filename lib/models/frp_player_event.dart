class FRPPlayerEvents {
  FRPPlayerEvents({
    required this.data,
    required this.playbackStatus,
    required this.icyMetaDetails,
  });

  final String? data;
  final String? playbackStatus;
  final String? icyMetaDetails;

  factory FRPPlayerEvents.fromJson(Map<String, dynamic> fromJsonData) {
    final name = fromJsonData["data"];
    final playback = fromJsonData["playbackStatus"];
    final icy = fromJsonData["icyMetaDetails"];
    return FRPPlayerEvents(
        data: name, playbackStatus: playback, icyMetaDetails: icy);
  }
}
