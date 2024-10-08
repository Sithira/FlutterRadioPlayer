import 'dart:convert';

class NowPlayingDataChanged {
  final String? title;

  NowPlayingDataChanged({
    required this.title,
  });

  factory NowPlayingDataChanged.fromJson(String data) {
    var json = jsonDecode(data);
    return NowPlayingDataChanged(
      title: json['title'],
    );
  }
}

class DeviceVolumeDataChanged {
  final double volume;
  final bool? isMuted;

  DeviceVolumeDataChanged({required this.volume, required this.isMuted});

  factory DeviceVolumeDataChanged.fromEvent(String data) {
    var json = jsonDecode(data);
    return DeviceVolumeDataChanged(
        volume: json['volume'], isMuted: json['isMuted']);
  }
}
