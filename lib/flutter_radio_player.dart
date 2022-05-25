
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterRadioPlayer {
  static const MethodChannel _methodChannel =
  MethodChannel('flutter_radio_player/method_channel');
  static const EventChannel _eventChannel =
  EventChannel('flutter_radio_player/event_channel');

  static Stream<String?>? _eventStream;

  FlutterRadioPlayer() {}

  static Future<String?> get platformVersion async {
    final String? version =
    await _methodChannel.invokeMethod('getPlatformVersion');
    return version;
  }

  static addMedia() async {
    await _methodChannel.invokeMethod("set_sources", {
      "media_sources": [
        {
          "url": "http://pavo.prostreaming.net:8052/stream",
          "title": "Z Fun Hundred",
          "isPrimary": false,
          "description": "TEST"
        },
        {
          "url": "http://209.133.216.3:7018/;stream.mp3",
          "title": "HiruFM",
          "isPrimary": true,
          "description": "HiruFM Live"
        }
      ]
    });
  }

  static initPeriodicMetaData() async {
    await _methodChannel.invokeMethod("init_periodic_metadata");
  }

  static addMediaSources() async {
    await _methodChannel.invokeMethod("add_sources", {
      "media_sources": [
        {"url": "1", "title": "some title", "primary": true},
        {"url": "2", "title": "some title 2", "primary": false}
      ]
    });
  }

  void initPlayer() {
     _eventStream ??= _eventChannel.receiveBroadcastStream().map<String?>((event) => event);
    print("Initializing Event Channels");
  }

  void play() async {
    await _methodChannel.invokeMethod("play");
  }

  void pause() async {
    await _methodChannel.invokeMethod("pause");
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

  void previous() async {
    await _methodChannel.invokeMethod("previous_source");
  }

  Stream<String?>? get frpEventStream {
    return _eventStream;
  }
}

