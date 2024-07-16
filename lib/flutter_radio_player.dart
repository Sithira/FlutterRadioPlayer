import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_radio_player/models/frp_source_modal.dart';

/// Wraps SwiftAudioManager (iOS) and ExoPlayer (Android) to provide seamless
/// Internet radio experience
///
/// AudioControls are integrated in the into the plugin to provide an seamless
/// experience
/// WearOS and watchOS are already handled by this plugin so that you have the
/// you will get the best of both worlds
class FlutterRadioPlayer {
  static const MethodChannel _methodChannel =
      MethodChannel('flutter_radio_player/method_channel');

  static const EventChannel _eventChannel =
      EventChannel('flutter_radio_player/event_channel');

  static Stream<String?>? _eventStream;

  FlutterRadioPlayer();

  /// Returns a [Future] of [String] of the players playback events
  Future<String> getPlaybackState() async {
    return await _methodChannel.invokeMethod("get_playback_state");
  }

  /// Initialize the player for the first time.
  /// This is will init the method channels and event channels that are
  /// necessary for the player to work in a reactive manner.
  /// You Only need to call this method once.
  void initPlayer() {
    if (kDebugMode) {
      print("Initialized Event Channels: Started");
    }
    _eventStream ??=
        _eventChannel.receiveBroadcastStream().map<String?>((event) => event);
    if (kDebugMode) {
      print("Initialized Event Channels: Completed");
    }
  }

  /// Add the media sources to the player.
  /// This will enable previous and next features if you are using the list feature
  void addMediaSources(FRPSource frpSource) async {
    await _methodChannel.invokeMethod("set_sources", frpSource.toJson());
  }

  /// Extract the Icy / ID3 meta data from stream
  void useIcyData(bool useIcyData) async {
    await _methodChannel.invokeMethod("use_icy_data", {"status": useIcyData});
  }

  /// Play current active media-item
  void play() async {
    await _methodChannel.invokeMethod("play");
  }

  /// Pause current active media-item
  void pause() async {
    await _methodChannel.invokeMethod("pause");
  }

  /// Seek to index of a media-item
  void seekToMediaSource(int position, bool playWhenReady) async {
    await _methodChannel.invokeMethod("seek_source_to_index",
        {"source_index": position, "play_when_ready": playWhenReady});
  }

  /// Stop the player. You need to re-initialize if you call this method
  void stop() async {
    await _methodChannel.invokeMethod("stop");
  }

  /// Play or Pause the current active media-item
  void playOrPause() async {
    await _methodChannel.invokeMethod("play_or_pause");
  }

  /// Plays the next song if there is any media-item in the list
  void next() async {
    await _methodChannel.invokeMethod("next_source");
  }

  /// Adjust the player volume along with the device itself
  void setVolume(double volume) async {
    await _methodChannel.invokeMethod("set_volume", {"volume": volume});
  }

  /// Plays the previous song if there is any media-item in the list
  void previous() async {
    await _methodChannel.invokeMethod("previous_source");
  }

  /// Returns [Stream] of events of the player. This includes
  /// - playback_status
  /// - icy_meta details changes
  /// - volume changes
  Stream<String?>? get frpEventStream {
    return _eventStream;
  }
}
