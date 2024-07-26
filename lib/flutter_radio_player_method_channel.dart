import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_radio_player/data/flutter_radio_player_event.dart';

import 'flutter_radio_player_platform_interface.dart';

/// An implementation of [FlutterRadioPlayerPlatform] that uses method channels.
class MethodChannelFlutterRadioPlayer extends FlutterRadioPlayerPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_radio_player');

  static const playbackStatusEventChannel =
      EventChannel("flutter_radio_player/playback_status");

  static const nowPlayingInfoEventChannel =
      EventChannel("flutter_radio_player/now_playing_info");

  static const deviceVolumeChangedEventChannel =
      EventChannel("flutter_radio_player/volume_control");

  Stream<bool>? _playbackStream;

  Stream<NowPlayingDataChanged>? _nowPlayingInfo;

  Stream<DeviceVolumeDataChanged>? _deviceVolumeChangedStream;

  @override
  Future<void> initialize(
      List<Map<String, String>> sources, bool playWhenReady) async {
    await methodChannel.invokeMethod<String>('initialize', {
      "sources": jsonEncode(sources),
      "playWhenReady": playWhenReady,
    });
  }

  @override
  Future<void> play() async {
    await methodChannel.invokeMethod<void>("play");
  }

  @override
  Future<void> pause() async {
    await methodChannel.invokeMethod<void>("pause");
  }

  @override
  Future<void> playOrPause() async {
    await methodChannel.invokeMethod<void>("playOrPause");
  }

  @override
  Future<void> changeVolume(double volume) async {
    await methodChannel.invokeMethod<void>("changeVolume", {"volume": volume});
  }

  @override
  Future<double?> getVolume() async {
    return await methodChannel.invokeMethod<double>("getVolume");
  }

  @override
  Future<void> nextSource() async {
    await methodChannel.invokeMethod("nextSource");
  }

  @override
  Future<void> previousSource() async {
    await methodChannel.invokeMethod("prevSource");
  }

  @override
  Future<void> jumpToSourceIndex(int index) async {
    await methodChannel.invokeMethod("jumpToItem", {"index": index});
  }

  @override
  Stream<bool> getIsPlayingStream() {
    if (_playbackStream != null) {
      return _playbackStream!;
    }

    var playbackStream = playbackStatusEventChannel
        .receiveBroadcastStream()
        .asBroadcastStream(onCancel: (sub) {
      sub.cancel();
      _playbackStream = null;
    });

    return playbackStream.map<bool>(
      (dynamic element) {
        return element as bool;
      },
    );
  }

  @override
  Stream<NowPlayingDataChanged?> getNowPlayingStream() {
    if (_nowPlayingInfo != null) {
      return _nowPlayingInfo!;
    }

    var playerReadyStream = nowPlayingInfoEventChannel
        .receiveBroadcastStream()
        .asBroadcastStream(onCancel: (sub) {
      sub.cancel();
      _nowPlayingInfo = null;
    });

    return playerReadyStream.map<NowPlayingDataChanged>((dynamic event) {
      return NowPlayingDataChanged.fromJson(event as String);
    });
  }

  @override
  Stream<DeviceVolumeDataChanged?> getDeviceVolumeChangedStream() {
    if (_deviceVolumeChangedStream != null) {
      return _deviceVolumeChangedStream!;
    }
    var deviceVolumeChangedStream = deviceVolumeChangedEventChannel
        .receiveBroadcastStream()
        .asBroadcastStream(onCancel: (sub) {
      sub.cancel();
      _deviceVolumeChangedStream = null;
    });

    return deviceVolumeChangedStream.map((dynamic event) {
      return DeviceVolumeDataChanged.fromEvent(event as String);
    });
  }
}
