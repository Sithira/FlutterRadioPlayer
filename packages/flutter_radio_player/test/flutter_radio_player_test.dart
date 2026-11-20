import 'dart:async';

import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_radio_player/src/flutter_radio_player.dart'
    show resetFlutterRadioPlayer;
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPlatform extends FlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin {
  final calls = <String>[];
  final events = StreamController<RadioPlayerState>.broadcast();
  int listens = 0;
  int cancels = 0;
  RadioPlayerState reply = const RadioPlayerState();
  Completer<RadioPlayerState>? pending;
  Object? error;

  @override
  Stream<RadioPlayerState> get stateStream => Stream.multi((c) {
    listens++;
    final sub = events.stream.listen(c.add);
    c.onCancel = () {
      cancels++;
      return sub.cancel();
    };
  });

  Future<RadioPlayerState> _record(String call) {
    calls.add(call);
    if (error != null) return Future.error(error!);
    return pending?.future ?? Future.value(reply);
  }

  @override
  Future<RadioPlayerState> setSources(
    List<RadioSource> sources, {
    int? initialIndex,
    bool autoPlay = false,
  }) => _record('setSources(${sources.length}, $initialIndex, $autoPlay)');

  @override
  Future<RadioPlayerState> setOptions(RadioPlayerOptions options) =>
      _record('setOptions(${options.wrapAround})');

  @override
  Future<RadioPlayerState> play({int? index}) => _record('play($index)');

  @override
  Future<RadioPlayerState> pause() => _record('pause');

  @override
  Future<RadioPlayerState> playOrPause() => _record('playOrPause');

  @override
  Future<RadioPlayerState> stop() => _record('stop');

  @override
  Future<RadioPlayerState> next() => _record('next');

  @override
  Future<RadioPlayerState> previous() => _record('previous');

  @override
  Future<RadioPlayerState> setVolume(double volume) =>
      _record('setVolume($volume)');
}

const _a = RadioSource(url: 'https://a.example/s', title: 'A');
const _b = RadioSource(url: 'https://b.example/s', title: 'B');
const _c = RadioSource(url: 'https://c.example/s', title: 'C');

const _paused = RadioPlayerState(
  status: PlaybackStatus.paused,
  sources: [_a, _b, _c],
  currentIndex: 0,
);
const _playing = RadioPlayerState(
  status: PlaybackStatus.playing,
  sources: [_a, _b, _c],
  currentIndex: 2,
);

void main() {
  late _MockPlatform platform;
  final player = FlutterRadioPlayer.instance;

  setUp(() {
    platform = _MockPlatform();
    FlutterRadioPlayerPlatform.instance = platform;
    resetFlutterRadioPlayer();
  });

  group('order and completion', () {
    test('unawaited calls reach the platform in call order', () {
      unawaited(player.setSources(const [_a, _b, _c]));
      unawaited(player.play(index: 2));
      unawaited(player.setVolume(0.5));
      expect(platform.calls, [
        'setSources(3, null, false)',
        'play(2)',
        'setVolume(0.5)',
      ]);
    });

    test('state reflects the reply when the future completes', () async {
      platform.pending = Completer();
      final done = player.play(index: 2);
      await pumpEventQueue();
      expect(player.state, const RadioPlayerState());

      platform.pending!.complete(_playing);
      await done;
      expect(player.state, _playing);
    });

    test('every command applies its reply', () async {
      final commands = <Future<void> Function()>[
        () => player.setSources(const [_a]),
        () => player.setOptions(const RadioPlayerOptions()),
        () => player.play(),
        () => player.pause(),
        () => player.playOrPause(),
        () => player.stop(),
        () => player.next(),
        () => player.previous(),
        () => player.setVolume(0.2),
      ];
      for (final (i, command) in commands.indexed) {
        platform.reply = RadioPlayerState(volume: i / 10);
        await command();
        expect(player.state.volume, i / 10);
      }
    });

    test('subscribes to the platform before sending the first command', () {
      unawaited(player.pause());
      expect(platform.listens, 1);
      expect(platform.calls, ['pause']);
    });
  });

  group('arguments', () {
    test(
      'initialIndex outside the list is a RangeError, nothing is sent',
      () async {
        expect(
          player.setSources(const [_a, _b], initialIndex: 2),
          throwsRangeError,
        );
        expect(
          player.setSources(const [_a, _b], initialIndex: -1),
          throwsRangeError,
        );
        expect(player.setSources(const [], initialIndex: 0), throwsRangeError);
        await pumpEventQueue();
        expect(platform.calls, isEmpty);
        expect(player.state, const RadioPlayerState());
      },
    );

    test('negative play index is a RangeError, nothing is sent', () async {
      expect(player.play(index: -1), throwsRangeError);
      await pumpEventQueue();
      expect(platform.calls, isEmpty);
    });

    test('argument errors come only through the future', () {
      late Future<void> future;
      expect(() => future = player.play(index: -1), returnsNormally);
      expect(future, throwsRangeError);
      expect(() => future = player.setVolume(double.nan), returnsNormally);
      expect(future, throwsArgumentError);
    });

    test('play index is never checked against cached state', () async {
      expect(player.state.sources, isEmpty);
      await player.play(index: 7);
      expect(platform.calls, ['play(7)']);
    });

    test('a native RangeError passes through unchanged', () async {
      platform.error = RangeError.index(7, const [_a], 'index');
      await expectLater(player.play(index: 7), throwsRangeError);
      expect(player.state, const RadioPlayerState());
    });

    test('volume is clamped, NaN rejected', () async {
      await player.setVolume(1.5);
      await player.setVolume(-0.5);
      await player.setVolume(0.25);
      await expectLater(player.setVolume(double.nan), throwsArgumentError);
      expect(platform.calls, [
        'setVolume(1.0)',
        'setVolume(0.0)',
        'setVolume(0.25)',
      ]);
    });

    test('setSources passes an unmodifiable copy', () async {
      final sources = [_a, _b];
      List<RadioSource>? received;
      FlutterRadioPlayerPlatform.instance = _CapturingPlatform((s) {
        received = s;
      });
      await player.setSources(sources);
      sources.add(_c);
      expect(received, hasLength(2));
      expect(() => received!.add(_c), throwsUnsupportedError);
    });
  });

  group('state stream', () {
    test('replays state to each new listener, then distinct changes', () async {
      player.state;
      platform.events.add(_paused);
      await pumpEventQueue();

      final first = <RadioPlayerState>[];
      final second = <RadioPlayerState>[];
      player.stateStream.listen(first.add);
      await pumpEventQueue();
      platform.events
        ..add(_paused)
        ..add(_playing)
        ..add(_playing);
      await pumpEventQueue();
      player.stateStream.listen(second.add);
      await pumpEventQueue();

      expect(first, [_paused, _playing]);
      expect(second, [_playing]);
    });

    test('replays the idle default before any snapshot', () async {
      expect(await player.stateStream.first, const RadioPlayerState());
    });

    test('state and stream agree after a reply', () async {
      final seen = <RadioPlayerState>[];
      player.stateStream.listen(seen.add);
      platform.reply = _playing;
      await player.play();
      await pumpEventQueue();
      expect(seen.last, _playing);
      expect(player.state, _playing);
    });

    test('one platform subscription for every kind of use', () async {
      player.stateStream.listen((_) {});
      player.stateStream.listen((_) {});
      player.addListener(() {});
      player.state;
      player.value;
      await player.play();
      await player.pause();
      expect(platform.listens, 1);
    });
  });

  group('ValueListenable', () {
    test('value is state', () async {
      player.state;
      platform.events.add(_paused);
      await pumpEventQueue();
      expect(player.value, _paused);
      expect(player.value, same(player.state));
    });

    test('listeners fire once per distinct state', () async {
      var calls = 0;
      player.addListener(() => calls++);
      platform.events
        ..add(_paused)
        ..add(_paused)
        ..add(_playing);
      await pumpEventQueue();
      expect(calls, 2);
      platform.reply = _playing;
      await player.play();
      expect(calls, 2);
    });

    test('listeners see the new value when called', () async {
      final values = <RadioPlayerState>[];
      player.addListener(() => values.add(player.value));
      platform.events.add(_playing);
      await pumpEventQueue();
      expect(values, [_playing]);
    });

    test(
      'removing the last listener keeps the platform subscription',
      () async {
        void listener() {}
        player.addListener(listener);
        player.removeListener(listener);
        await pumpEventQueue();
        expect(platform.cancels, 0);
        platform.events.add(_playing);
        await pumpEventQueue();
        expect(player.state, _playing);
      },
    );
  });

  group('platform changes', () {
    test('reset returns to idle, notifies and reattaches lazily', () async {
      player.state;
      platform.events.add(_playing);
      await pumpEventQueue();
      final seen = <RadioPlayerState>[];
      player.stateStream.listen(seen.add);
      await pumpEventQueue();

      final next = _MockPlatform();
      FlutterRadioPlayerPlatform.instance = next;
      resetFlutterRadioPlayer();
      await pumpEventQueue();
      expect(player.state, const RadioPlayerState());
      expect(seen, [_playing, const RadioPlayerState()]);
      expect(platform.cancels, 1);
      expect(next.listens, 1);
    });

    test('a newly registered platform is attached on next use', () async {
      player.state;
      final next = _MockPlatform();
      FlutterRadioPlayerPlatform.instance = next;
      await player.pause();
      expect(next.calls, ['pause']);
      expect(next.listens, 1);
      expect(platform.cancels, 1);
    });
  });
}

class _CapturingPlatform extends FlutterRadioPlayerPlatform
    with MockPlatformInterfaceMixin {
  _CapturingPlatform(this.onSources);

  final void Function(List<RadioSource>) onSources;

  @override
  Stream<RadioPlayerState> get stateStream => const Stream.empty();

  @override
  Future<RadioPlayerState> setSources(
    List<RadioSource> sources, {
    int? initialIndex,
    bool autoPlay = false,
  }) async {
    onSources(sources);
    return const RadioPlayerState();
  }
}
