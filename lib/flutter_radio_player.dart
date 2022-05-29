import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_radio_player/models/frp_source_modal.dart';

class FlutterRadioPlayer {
  static const MethodChannel _methodChannel =
      MethodChannel('flutter_radio_player/method_channel');

  static const EventChannel _eventChannel =
      EventChannel('flutter_radio_player/event_channel');

  static Stream<String?>? _eventStream;

  FlutterRadioPlayer() {}

  Future<String> getPlaybackState() async {
    return await _methodChannel.invokeMethod("get_playback_state");
  }

  void initPlayer() {
    print("Initialized Event Channels: Started");
    _eventStream ??=
        _eventChannel.receiveBroadcastStream().map<String?>((event) => event);
    print("Initialized Event Channels: Completed");

  }

  void addMediaSources(FRPSource frpSource) async {
    await _methodChannel.invokeMethod("set_sources", frpSource.toJson());
  }

  void useIcyData(bool useIcyData) async {
    await _methodChannel.invokeMethod("use_icy_data", {"status": useIcyData});
  }

  void play() async {
    await _methodChannel.invokeMethod("play");
  }

  void pause() async {
    await _methodChannel.invokeMethod("pause");
  }

  void seekToMediaSource(int position, bool playWhenReady) async {
    await _methodChannel.invokeMethod("seek_source_to_index",
        {"source_index": position, "play_when_ready": playWhenReady});
  }

  void stop() async {
    await _methodChannel.invokeMethod("stop");
  }

  void playOrPause() async {
    await _methodChannel.invokeMethod("play_or_pause");
  }

  void next() async {
    await _methodChannel.invokeMethod("next_source");
  }

  void setVolume(double volume) async {
    await _methodChannel.invokeMethod("set_volume", {"volume": volume});
  }

  void previous() async {
    await _methodChannel.invokeMethod("previous_source");
  }

  Stream<String?>? get frpEventStream {
    return _eventStream;
  }
}
