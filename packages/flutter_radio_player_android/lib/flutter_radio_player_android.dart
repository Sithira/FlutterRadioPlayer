import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

import 'src/messages.g.dart';

class FlutterRadioPlayerAndroid extends FlutterRadioPlayerPlatform {
  FlutterRadioPlayerAndroid({
    @visibleForTesting RadioPlayerHostApi? hostApi,
    @visibleForTesting Stream<RadioPlayerStateMessage> Function()? stateEvents,
  })  : _hostApi = hostApi ?? RadioPlayerHostApi(),
        _stateEvents = stateEvents ?? onStateChanged;

  final RadioPlayerHostApi _hostApi;
  final Stream<RadioPlayerStateMessage> Function() _stateEvents;

  final StreamController<RadioPlayerState> _stateController =
      StreamController<RadioPlayerState>.broadcast();
  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<NowPlayingInfo> _nowPlayingController =
      StreamController<NowPlayingInfo>.broadcast();
  final StreamController<VolumeInfo> _volumeController =
      StreamController<VolumeInfo>.broadcast();

  late final Stream<RadioPlayerState> _stateStream =
      Stream<RadioPlayerState>.multi((controller) {
    final latest = _latest;
    if (latest != null) {
      controller.add(latest);
    }
    final subscription = _stateController.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = subscription.cancel;
  }, isBroadcast: true);

  late final Stream<bool> _isPlayingStream = _isPlayingController.stream;
  late final Stream<NowPlayingInfo> _nowPlayingStream =
      _nowPlayingController.stream;
  late final Stream<VolumeInfo> _volumeStream = _volumeController.stream;

  StreamSubscription<RadioPlayerStateMessage>? _subscription;
  List<RadioSource> _sources = const [];
  RadioPlayerState? _latest;

  static void registerWith() {
    FlutterRadioPlayerPlatform.instance = FlutterRadioPlayerAndroid();
  }

  void _ensureSubscribed() {
    _subscription ??= _stateEvents().listen(
      _onMessage,
      onError: _stateController.addError,
    );
  }

  void _onMessage(RadioPlayerStateMessage message) {
    final previous = _latest;
    final next = _toState(message);
    _latest = next;
    _stateController.add(next);
    if (previous == null) {
      return;
    }
    if ((previous.status == PlaybackStatus.playing) !=
        (next.status == PlaybackStatus.playing)) {
      _isPlayingController.add(next.status == PlaybackStatus.playing);
    }
    if (previous.nowPlaying?.title != next.nowPlaying?.title) {
      _nowPlayingController.add(NowPlayingInfo(title: next.nowPlaying?.title));
    }
    if (previous.volume != next.volume) {
      _volumeController.add(
        VolumeInfo(volume: next.volume, isMuted: next.volume == 0),
      );
    }
  }

  RadioPlayerState _toState(RadioPlayerStateMessage message) {
    final index = message.currentIndex;
    final title = message.nowPlayingTitle;
    final error = message.error;
    return RadioPlayerState(
      status: PlaybackStatus.values.byName(message.status.name),
      currentIndex: index,
      currentSource: index != null && index >= 0 && index < _sources.length
          ? _sources[index]
          : null,
      nowPlaying: title == null ? null : NowPlayingInfo(title: title),
      volume: message.volume,
      error: error == null
          ? null
          : RadioPlayerError(
              code: RadioPlayerErrorCode.values.byName(error.code.name),
              message: error.message,
            ),
    );
  }

  @override
  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) {
    _ensureSubscribed();
    _sources = List.of(sources);
    return _hostApi.initialize(
      sources.map(_toMessage).toList(),
      playWhenReady,
    );
  }

  @override
  Future<void> play() => _hostApi.play();

  @override
  Future<void> pause() => _hostApi.pause();

  @override
  Future<void> playOrPause() => _hostApi.playOrPause();

  @override
  Future<void> setVolume(double volume) => _hostApi.setVolume(volume);

  @override
  Future<double> getVolume() => _hostApi.getVolume();

  @override
  Future<void> nextSource() => _hostApi.nextSource();

  @override
  Future<void> previousSource() => _hostApi.previousSource();

  @override
  Future<void> jumpToSourceAtIndex(int index) =>
      _hostApi.jumpToSourceAtIndex(index);

  @override
  Future<void> dispose() async {
    await _hostApi.dispose();
    _sources = const [];
    _onMessage(await _hostApi.getState());
  }

  @override
  Stream<bool> get isPlayingStream {
    _ensureSubscribed();
    return _isPlayingStream;
  }

  @override
  Stream<NowPlayingInfo> get nowPlayingStream {
    _ensureSubscribed();
    return _nowPlayingStream;
  }

  @override
  Stream<VolumeInfo> get volumeStream {
    _ensureSubscribed();
    return _volumeStream;
  }

  @override
  RadioPlayerState get state {
    _ensureSubscribed();
    return _latest ?? const RadioPlayerState();
  }

  @override
  Stream<RadioPlayerState> get stateStream {
    _ensureSubscribed();
    return _stateStream;
  }

  static RadioSourceMessage _toMessage(RadioSource source) {
    return RadioSourceMessage(
      url: source.url,
      title: source.title,
      artwork: source.artwork,
    );
  }
}
