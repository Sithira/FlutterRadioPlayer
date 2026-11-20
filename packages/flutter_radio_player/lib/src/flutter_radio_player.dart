import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';

/// The radio player. There is one per process, shared by every Flutter
/// engine: use [instance].
///
/// ```dart
/// final player = FlutterRadioPlayer.instance;
/// await player.setSources(const [
///   RadioSource(url: 'https://example.com/live.mp3', title: 'My Radio'),
/// ]);
/// await player.play();
/// ```
///
/// Commands apply in call order, awaited or not. When a command's future
/// completes, [state] already reflects it. With no sources, transport
/// commands do nothing. Only invalid arguments throw, through the returned
/// future; playback problems show up in [state].
class FlutterRadioPlayer implements ValueListenable<RadioPlayerState> {
  FlutterRadioPlayer._();

  /// The shared player.
  static final FlutterRadioPlayer instance = FlutterRadioPlayer._();

  RadioPlayerState _state = const RadioPlayerState();
  final _changes = StreamController<RadioPlayerState>.broadcast(sync: true);
  final _notifier = _Notifier();
  FlutterRadioPlayerPlatform? _platform;
  StreamSubscription<RadioPlayerState>? _subscription;

  late final Stream<RadioPlayerState> _stateStream = Stream.multi((listener) {
    listener.add(_state);
    final subscription = _changes.stream.listen(
      listener.addSync,
      onDone: listener.closeSync,
    );
    listener
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = subscription.cancel;
  }, isBroadcast: true);

  /// The latest state. Idle with no sources and volume 1.0 until the first
  /// native snapshot arrives.
  RadioPlayerState get state {
    _attach();
    return _state;
  }

  /// The current state, then every distinct change. Each new listener first
  /// receives [state]; two equal states are never emitted in a row.
  Stream<RadioPlayerState> get stateStream {
    _attach();
    return _stateStream;
  }

  /// Same as [state].
  @override
  RadioPlayerState get value => state;

  /// Calls [listener] once per distinct state, when [stateStream] emits.
  /// Removing the last listener keeps the player attached.
  @override
  void addListener(VoidCallback listener) {
    _attach();
    _notifier.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  /// Replaces the source list.
  ///
  /// A source that is playing keeps playing if it is still in [sources]
  /// (matched by [RadioSource.id]); otherwise the first source, or
  /// [initialIndex] if given, becomes current and nothing connects until
  /// playback is requested. [autoPlay] then acts like [play]. An empty list
  /// stops playback. Volume and options are not changed.
  ///
  /// Throws a [RangeError] if [initialIndex] is outside [sources].
  Future<void> setSources(
    List<RadioSource> sources, {
    int? initialIndex,
    bool autoPlay = false,
  }) async {
    if (initialIndex != null) {
      RangeError.checkValidIndex(
        initialIndex,
        sources,
        'initialIndex',
        sources.length,
      );
    }
    _apply(
      await _send().setSources(
        List.unmodifiable(sources),
        initialIndex: initialIndex,
        autoPlay: autoPlay,
      ),
    );
  }

  /// Replaces the options of the shared player. Takes effect at once.
  Future<void> setOptions(RadioPlayerOptions options) async {
    _apply(await _send().setOptions(options));
  }

  /// Plays the current source, or makes source [index] current and plays it.
  ///
  /// Connects if the stream is not loaded, so playback starts at live audio.
  /// Throws a [RangeError] if [index] is negative or not below the number of
  /// sources the native player holds when the call is applied.
  Future<void> play({int? index}) async {
    if (index != null) RangeError.checkNotNegative(index, 'index');
    _apply(await _send().play(index: index));
  }

  /// Pauses. Lock-screen and notification controls stay.
  Future<void> pause() async => _apply(await _send().pause());

  /// Pauses if playback is requested ([RadioPlayerState.isPlaying]),
  /// otherwise plays. Decided natively, never on a stale [state].
  Future<void> playOrPause() async => _apply(await _send().playOrPause());

  /// Turns the radio off: stops playback, closes the stream and removes the
  /// notification and lock-screen info. Keeps sources, the current index,
  /// volume and options; [play] starts again.
  Future<void> stop() async => _apply(await _send().stop());

  /// Moves to the next source and keeps the play state. Wraps at the end if
  /// [RadioPlayerOptions.wrapAround] is set.
  Future<void> next() async => _apply(await _send().next());

  /// Moves to the previous source and keeps the play state. Wraps at the
  /// start if [RadioPlayerOptions.wrapAround] is set.
  Future<void> previous() async => _apply(await _send().previous());

  /// Sets the player volume, clamped to 0.0-1.0. Not the device volume.
  ///
  /// Throws an [ArgumentError] for `double.nan`.
  Future<void> setVolume(double volume) async {
    if (volume.isNaN) throw ArgumentError.value(volume, 'volume', 'is NaN');
    _apply(await _send().setVolume(volume.clamp(0.0, 1.0)));
  }

  FlutterRadioPlayerPlatform _send() {
    _attachTo(FlutterRadioPlayerPlatform.instance);
    return _platform!;
  }

  void _attach() {
    final FlutterRadioPlayerPlatform platform;
    try {
      platform = FlutterRadioPlayerPlatform.instance;
    } on StateError {
      return;
    }
    _attachTo(platform);
  }

  void _attachTo(FlutterRadioPlayerPlatform platform) {
    if (identical(platform, _platform) && _subscription != null) return;
    _subscription?.cancel();
    _platform = platform;
    _subscription = platform.stateStream.listen(_apply);
  }

  void _apply(RadioPlayerState state) {
    if (state == _state) return;
    _state = state;
    _changes.add(state);
    _notifier.notify();
  }

  void _reset() {
    _subscription?.cancel();
    _subscription = null;
    _platform = null;
    _apply(const RadioPlayerState());
  }
}

/// Detaches [FlutterRadioPlayer.instance] from its platform and resets its
/// state to idle. For the testing fake only.
void resetFlutterRadioPlayer() => FlutterRadioPlayer.instance._reset();

class _Notifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
