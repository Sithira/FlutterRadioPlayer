import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

import 'src/messages.g.dart';

class FlutterRadioPlayerIos extends FlutterRadioPlayerPlatform {
  FlutterRadioPlayerIos({
    @visibleForTesting RadioPlayerHostApi? hostApi,
    @visibleForTesting Stream<RadioPlayerStateMessage> Function()? stateEvents,
  })  : _hostApi = hostApi ?? RadioPlayerHostApi(),
        _stateEvents = stateEvents ?? onStateChanged;

  final RadioPlayerHostApi _hostApi;
  final Stream<RadioPlayerStateMessage> Function() _stateEvents;

  StreamSubscription<RadioPlayerStateMessage>? _stateSubscription;
  List<RadioSource> _sources = const [];
  RadioPlayerStateMessage? _latestMessage;
  RadioPlayerState? _latest;

  final Set<MultiStreamController<RadioPlayerState>> _stateListeners = {};
  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<NowPlayingInfo> _nowPlayingController =
      StreamController<NowPlayingInfo>.broadcast();
  final StreamController<VolumeInfo> _volumeController =
      StreamController<VolumeInfo>.broadcast();

  late final Stream<RadioPlayerState> _stateStream =
      Stream<RadioPlayerState>.multi(
    (controller) {
      final latest = _latest;
      if (latest != null) {
        controller.add(latest);
      }
      _stateListeners.add(controller);
      controller.onCancel = () => _stateListeners.remove(controller);
    },
    isBroadcast: true,
  );
  late final Stream<bool> _isPlayingStream = _isPlayingController.stream;
  late final Stream<NowPlayingInfo> _nowPlayingStream =
      _nowPlayingController.stream;
  late final Stream<VolumeInfo> _volumeStream = _volumeController.stream;

  static void registerWith() {
    FlutterRadioPlayerPlatform.instance = FlutterRadioPlayerIos();
  }

  @override
  Future<void> initialize(
    List<RadioSource> sources, {
    bool playWhenReady = false,
  }) {
    _ensureSubscribed();
    _sources = List.of(sources);
    _rederiveState();
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
    _onStateMessage(await _hostApi.getState());
  }

  /// The latest known player state.
  ///
  /// This is eventually consistent: it reflects the last snapshot received
  /// from the native side, which may lag behind a command that has just been
  /// dispatched.
  @override
  RadioPlayerState get state {
    _ensureSubscribed();
    return _latest ?? const RadioPlayerState();
  }

  /// A broadcast stream of player state snapshots.
  ///
  /// Every new listener first receives the latest snapshot, if one has arrived,
  /// followed by live updates.
  @override
  Stream<RadioPlayerState> get stateStream {
    _ensureSubscribed();
    return _stateStream;
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

  void _ensureSubscribed() {
    _stateSubscription ??= _stateEvents().listen(
      _onStateMessage,
      onError: _onStateError,
    );
  }

  void _onStateError(Object error, StackTrace stackTrace) {
    for (final listener in _stateListeners.toList()) {
      listener.addError(error, stackTrace);
    }
  }

  void _rederiveState() {
    final message = _latestMessage;
    if (message == null) {
      return;
    }
    final current = _toState(message);
    if (current == _latest) {
      return;
    }
    _latest = current;
    for (final listener in _stateListeners.toList()) {
      listener.add(current);
    }
  }

  void _onStateMessage(RadioPlayerStateMessage message) {
    _latestMessage = message;
    final previous = _latest;
    final current = _toState(message);
    if (current == previous) {
      return;
    }
    _latest = current;

    for (final listener in _stateListeners.toList()) {
      listener.add(current);
    }

    if (previous == null) {
      return;
    }

    final wasPlaying = _isPlaying(previous);
    final isPlaying = _isPlaying(current);
    if (wasPlaying != isPlaying) {
      _isPlayingController.add(isPlaying);
    }
    if (previous.nowPlaying?.title != current.nowPlaying?.title) {
      _nowPlayingController
          .add(NowPlayingInfo(title: current.nowPlaying?.title));
    }
    if (previous.volume != current.volume) {
      _volumeController.add(
        VolumeInfo(volume: current.volume, isMuted: current.volume == 0),
      );
    }
  }

  static bool _isPlaying(RadioPlayerState state) =>
      state.status == PlaybackStatus.playing ||
      state.status == PlaybackStatus.loading;

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

  static RadioSourceMessage _toMessage(RadioSource source) {
    return RadioSourceMessage(
      url: source.url,
      title: source.title,
      artwork: source.artwork,
    );
  }
}
