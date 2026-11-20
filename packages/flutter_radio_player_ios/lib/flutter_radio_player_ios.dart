import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

import 'src/messages.g.dart';

/// The iOS implementation of [FlutterRadioPlayerPlatform].
class FlutterRadioPlayerIos extends FlutterRadioPlayerPlatform {
  /// Creates the iOS implementation.
  FlutterRadioPlayerIos({
    @visibleForTesting RadioPlayerHostApi? hostApi,
    @visibleForTesting Stream<RadioPlayerStateMessage> Function()? stateEvents,
  }) : _hostApi = hostApi ?? RadioPlayerHostApi(),
       _stateEvents = stateEvents ?? onStateChanged;

  final RadioPlayerHostApi _hostApi;
  final Stream<RadioPlayerStateMessage> Function() _stateEvents;

  late final Stream<RadioPlayerState> _stateStream = _stateEvents().map(
    stateFromMessage,
  );

  /// Registers this class as the platform implementation.
  static void registerWith() {
    FlutterRadioPlayerPlatform.instance = FlutterRadioPlayerIos();
  }

  @override
  Stream<RadioPlayerState> get stateStream => _stateStream;

  @override
  Future<RadioPlayerState> setSources(
    List<RadioSource> sources, {
    int? initialIndex,
    bool autoPlay = false,
  }) => _reply(
    _hostApi.setSources(
      sources.map(sourceToMessage).toList(),
      initialIndex,
      autoPlay,
    ),
  );

  @override
  Future<RadioPlayerState> setOptions(RadioPlayerOptions options) =>
      _reply(_hostApi.setOptions(optionsToMessage(options)));

  @override
  Future<RadioPlayerState> play({int? index}) => _reply(_hostApi.play(index));

  @override
  Future<RadioPlayerState> pause() => _reply(_hostApi.pause());

  @override
  Future<RadioPlayerState> playOrPause() => _reply(_hostApi.playOrPause());

  @override
  Future<RadioPlayerState> stop() => _reply(_hostApi.stop());

  @override
  Future<RadioPlayerState> next() => _reply(_hostApi.next());

  @override
  Future<RadioPlayerState> previous() => _reply(_hostApi.previous());

  @override
  Future<RadioPlayerState> setVolume(double volume) =>
      _reply(_hostApi.setVolume(volume));

  Future<RadioPlayerState> _reply(Future<RadioPlayerStateMessage> reply) async {
    try {
      return stateFromMessage(await reply);
    } on PlatformException catch (e) {
      if (e.code == 'invalid_index') {
        throw RangeError(e.message ?? 'Index out of range');
      }
      rethrow;
    }
  }
}

/// Maps a native state message to a [RadioPlayerState].
@visibleForTesting
RadioPlayerState stateFromMessage(RadioPlayerStateMessage message) {
  final title = message.nowPlayingTitle;
  final error = message.error;
  return RadioPlayerState(
    status: PlaybackStatus.values.byName(message.status.name),
    sources: List.unmodifiable(message.sources.map(sourceFromMessage)),
    currentIndex: message.currentIndex,
    nowPlaying: title == null || title.isEmpty
        ? null
        : NowPlayingInfo(title: title),
    volume: message.volume,
    error: error == null
        ? null
        : RadioPlayerError(
            code: RadioPlayerErrorCode.values.byName(error.code.name),
            message: error.message,
          ),
  );
}

/// Maps a native source message to a [RadioSource].
@visibleForTesting
RadioSource sourceFromMessage(RadioSourceMessage message) => RadioSource(
  id: message.id,
  url: message.url,
  title: message.title,
  artwork: message.artwork,
  headers: Map.unmodifiable(message.headers),
);

/// Maps a [RadioSource] to its native message.
@visibleForTesting
RadioSourceMessage sourceToMessage(RadioSource source) => RadioSourceMessage(
  id: source.id,
  url: source.url,
  title: source.title,
  artwork: source.artwork,
  headers: source.headers,
);

/// Maps [RadioPlayerOptions] to its native message.
@visibleForTesting
RadioPlayerOptionsMessage optionsToMessage(RadioPlayerOptions options) =>
    RadioPlayerOptionsMessage(
      wrapAround: options.wrapAround,
      reconnectGiveUpAfterMillis: options.reconnect.giveUpAfter.inMilliseconds,
      androidStopOnTaskRemoved: options.android.stopOnTaskRemoved,
      androidNotificationIcon: options.android.notificationIcon,
    );
