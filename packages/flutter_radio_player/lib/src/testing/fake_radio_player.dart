import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

import '../flutter_radio_player.dart';

/// An in-memory player for tests, following the same rules as the native
/// players: `setSources` selection, kept play state on `next` and
/// `previous`, wrap-around, the volume clamp and the index [RangeError].
/// `play` goes straight to [PlaybackStatus.playing].
///
/// ```dart
/// final fake = FakeRadioPlayer.install();
/// await tester.pumpWidget(const MyApp());
/// fake.state = fake.state.copyWith(
///   nowPlaying: const NowPlayingInfo(title: 'Miles Davis - So What'),
/// );
/// ```
class FakeRadioPlayer extends FlutterRadioPlayerPlatform {
  FakeRadioPlayer._();

  /// Registers a new fake as the platform and resets
  /// [FlutterRadioPlayer.instance] to idle. Call it at the start of every
  /// test; the singleton object stays the same.
  static FakeRadioPlayer install() {
    final fake = FakeRadioPlayer._();
    FlutterRadioPlayerPlatform.instance = fake;
    resetFlutterRadioPlayer();
    return fake;
  }

  final _events = StreamController<RadioPlayerState>.broadcast(sync: true);
  RadioPlayerState _state = const RadioPlayerState();

  /// Commands received, in order, e.g. `play`, `play(index: 2)`, `pause`,
  /// `stop`, `setVolume(0.5)`.
  final List<String> calls = [];

  /// The options last set with `setOptions`.
  RadioPlayerOptions options = const RadioPlayerOptions();

  /// The fake's current state.
  RadioPlayerState get state => _state;

  /// Pushes [state] as if the native player had emitted it.
  set state(RadioPlayerState state) {
    _state = state;
    _events.add(state);
  }

  @override
  Stream<RadioPlayerState> get stateStream => Stream.multi((listener) {
    listener.add(_state);
    final subscription = _events.stream.listen(listener.addSync);
    listener.onCancel = subscription.cancel;
  });

  @override
  Future<RadioPlayerState> setSources(
    List<RadioSource> sources, {
    int? initialIndex,
    bool autoPlay = false,
  }) {
    calls.add(
      'setSources(${sources.length}'
      '${initialIndex == null ? '' : ', initialIndex: $initialIndex'}'
      '${autoPlay ? ', autoPlay: true' : ''})',
    );
    if (initialIndex != null &&
        (initialIndex < 0 || initialIndex >= sources.length)) {
      return Future.error(RangeError.index(initialIndex, sources));
    }
    if (sources.isEmpty) {
      return _reply(RadioPlayerState(volume: _state.volume));
    }
    final previous = _state.currentSource;
    final index = initialIndex ?? _follow(previous, sources);
    final current = sources[index];
    final keep =
        previous != null &&
        previous.id == current.id &&
        previous.url == current.url &&
        mapEquals(previous.headers, current.headers);
    _state = keep
        ? _state.copyWith(
            sources: List.unmodifiable(sources),
            currentIndex: index,
          )
        : RadioPlayerState(
            status: PlaybackStatus.paused,
            sources: List.unmodifiable(sources),
            currentIndex: index,
            volume: _state.volume,
          );
    if (autoPlay) _startPlaying();
    return _reply(_state);
  }

  int _follow(RadioSource? previous, List<RadioSource> sources) {
    if (previous == null) return 0;
    final oldIndex = _state.currentIndex!;
    if (oldIndex < sources.length && sources[oldIndex].id == previous.id) {
      return oldIndex;
    }
    final match = sources.indexWhere((s) => s.id == previous.id);
    return match < 0 ? 0 : match;
  }

  @override
  Future<RadioPlayerState> setOptions(RadioPlayerOptions options) {
    calls.add('setOptions');
    this.options = options;
    return _reply(_state);
  }

  @override
  Future<RadioPlayerState> play({int? index}) {
    calls.add(index == null ? 'play' : 'play(index: $index)');
    if (_state.sources.isEmpty) return _reply(_state);
    if (index != null) {
      if (index < 0 || index >= _state.sources.length) {
        return Future.error(RangeError.index(index, _state.sources));
      }
      if (index != _state.currentIndex) _switchTo(index);
    }
    _startPlaying();
    return _reply(_state);
  }

  @override
  Future<RadioPlayerState> pause() {
    calls.add('pause');
    if (_state.sources.isNotEmpty) {
      _state = _state.copyWith(status: PlaybackStatus.paused, error: null);
    }
    return _reply(_state);
  }

  @override
  Future<RadioPlayerState> playOrPause() {
    calls.add('playOrPause');
    if (_state.sources.isNotEmpty) {
      if (_state.isPlaying) {
        _state = _state.copyWith(status: PlaybackStatus.paused, error: null);
      } else {
        _startPlaying();
      }
    }
    return _reply(_state);
  }

  @override
  Future<RadioPlayerState> stop() {
    calls.add('stop');
    if (_state.sources.isNotEmpty) {
      _state = _state.copyWith(
        status: PlaybackStatus.paused,
        nowPlaying: null,
        error: null,
      );
    }
    return _reply(_state);
  }

  @override
  Future<RadioPlayerState> next() {
    calls.add('next');
    _step(1);
    return _reply(_state);
  }

  @override
  Future<RadioPlayerState> previous() {
    calls.add('previous');
    _step(-1);
    return _reply(_state);
  }

  @override
  Future<RadioPlayerState> setVolume(double volume) {
    calls.add('setVolume($volume)');
    if (volume.isNaN) {
      return Future.error(ArgumentError.value(volume, 'volume', 'is NaN'));
    }
    _state = _state.copyWith(volume: volume.clamp(0.0, 1.0));
    return _reply(_state);
  }

  void _step(int delta) {
    final count = _state.sources.length;
    if (count < 2) return;
    var index = _state.currentIndex! + delta;
    if (index < 0 || index >= count) {
      if (!options.wrapAround) return;
      index = (index + count) % count;
    }
    final wasPlaying = _state.isPlaying;
    _switchTo(index);
    if (wasPlaying) _startPlaying();
  }

  void _switchTo(int index) {
    _state = _state.copyWith(
      status: PlaybackStatus.paused,
      currentIndex: index,
      nowPlaying: null,
      error: null,
    );
  }

  void _startPlaying() {
    _state = _state.copyWith(status: PlaybackStatus.playing, error: null);
  }

  Future<RadioPlayerState> _reply(RadioPlayerState state) =>
      Future.value(state);
}
