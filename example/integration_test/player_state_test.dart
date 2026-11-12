import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _sources = [
  RadioSource(
    url: 'https://s2-webradio.antenne.de/chillout?icy=https',
    title: 'Antenne Chillout',
  ),
  RadioSource(
    url:
        'https://radio.lotustechnologieslk.net:2020/stream/sunfmgarden?icy=https',
    title: 'SunFM - Sri Lanka',
  ),
  RadioSource(
    url: 'http://stream.riverradio.com:8000/wcvofm.aac',
    title: 'River Radio',
  ),
];

const _networkTimeout = Duration(seconds: 45);

class _Observation {
  _Observation(this.elapsed, this.state);
  final Duration elapsed;
  final RadioPlayerState state;
}

class _Recorder {
  _Recorder(this.player, this.label) {
    _subscription = player.stateStream.listen((state) {
      observations.add(_Observation(_clock.elapsed, state));
    });
  }

  final FlutterRadioPlayer player;
  final String label;
  final List<_Observation> observations = [];
  final Stopwatch _clock = Stopwatch()..start();
  late final StreamSubscription<RadioPlayerState> _subscription;

  Future<RadioPlayerState?> waitFor(
    bool Function(RadioPlayerState) predicate, {
    Duration timeout = _networkTimeout,
  }) async {
    final deadline = _clock.elapsed + timeout;
    while (_clock.elapsed < deadline) {
      for (final o in observations) {
        if (predicate(o.state)) return o.state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  Future<RadioPlayerState?> waitForNew(
    bool Function(RadioPlayerState) predicate, {
    Duration timeout = _networkTimeout,
    int? from,
  }) async {
    final start = from ?? observations.length;
    final deadline = _clock.elapsed + timeout;
    while (_clock.elapsed < deadline) {
      for (var i = start; i < observations.length; i++) {
        if (predicate(observations[i].state)) return observations[i].state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  Duration? timeOf(bool Function(RadioPlayerState) predicate) {
    for (final o in observations) {
      if (predicate(o.state)) return o.elapsed;
    }
    return null;
  }

  String describe(RadioPlayerState s) {
    final err = s.error == null
        ? ''
        : ' err=${s.error!.code.name}(${s.error!.message})';
    final title = s.nowPlaying?.title;
    return '${s.status.name}[i=${s.currentIndex} vol=${s.volume.toStringAsFixed(2)}'
        '${title == null ? '' : ' title="$title"'}$err]';
  }

  void printLog() {
    final platform = Platform.isAndroid ? 'ANDROID' : 'IOS';
    // ignore: avoid_print
    print(
      'SMOKE[$platform] $label: ${observations.map((o) => '+${o.elapsed.inMilliseconds}ms ${describe(o.state)}').join(' -> ')}',
    );
  }

  void expectConsistent() {
    for (var i = 0; i < observations.length; i++) {
      final state = observations[i].state;
      expect(
        state.nowPlaying?.title != null && state.currentIndex == null,
        isFalse,
        reason: 'title without index at #$i: ${describe(state)}',
      );
      if (i > 0) {
        expect(
          state,
          isNot(observations[i - 1].state),
          reason: 'duplicate consecutive snapshot at #$i: ${describe(state)}',
        );
      }
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
  }
}

void note(String message) {
  final platform = Platform.isAndroid ? 'ANDROID' : 'IOS';
  // ignore: avoid_print
  print('SMOKE[$platform] NOTE: $message');
}

bool _active(RadioPlayerState s) =>
    s.status == PlaybackStatus.loading || s.status == PlaybackStatus.playing;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final player = FlutterRadioPlayer();
  _Recorder? recorder;

  _Recorder record(String label) => recorder = _Recorder(player, label);

  setUp(() async {
    await player.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  tearDown(() async {
    recorder?.printLog();
    recorder?.expectConsistent();
    await recorder?.close();
    recorder = null;
    await player.dispose();
  });

  testWidgets(
    '1. transport calls before initialize() do not throw and stay idle',
    (tester) async {
      final r = record('1 before initialize');
      await player.play();
      await player.pause();
      await player.playOrPause();
      await player.setVolume(0.2);
      await player.nextSource();
      await player.previousSource();
      await player.jumpToSourceAtIndex(1);
      final volume = await player.getVolume();
      note('getVolume before initialize = $volume');
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(player.state.status, PlaybackStatus.idle);
      expect(
        r.observations.where((o) => o.state.status != PlaybackStatus.idle),
        isEmpty,
      );
    },
  );

  testWidgets('2. initialize(playWhenReady: true) leaves idle and starts', (
    tester,
  ) async {
    final r = record('2 initialize playWhenReady');
    await player.initialize(_sources, playWhenReady: true);
    final active = await r.waitFor(_active);
    expect(
      active,
      isNotNull,
      reason:
          'never left idle: ${r.observations.map((o) => r.describe(o.state))}',
    );
    final playing = await r.waitFor((s) => s.status == PlaybackStatus.playing);
    note(
      'time to loading=${r.timeOfOrNull(PlaybackStatus.loading)} time to playing=${r.timeOfOrNull(PlaybackStatus.playing)} reachedPlaying=${playing != null}',
    );
    final snapshot = (playing ?? active)!;
    expect(snapshot.currentIndex, 0);
    expect(snapshot.currentSource, _sources[0]);
  });

  testWidgets('3. pause gives paused, play returns to loading/playing', (
    tester,
  ) async {
    final r = record('3 pause/play');
    await player.initialize(_sources, playWhenReady: true);
    expect(
      await r.waitFor((s) => s.status == PlaybackStatus.playing),
      isNotNull,
      reason: 'precondition: playing',
    );
    final m1 = r.observations.length;
    await player.pause();
    expect(
      await r.waitForNew(
        (s) => s.status == PlaybackStatus.paused,
        timeout: const Duration(seconds: 10),
        from: m1,
      ),
      isNotNull,
      reason: 'paused',
    );
    final mark = r.observations.length;
    await player.play();
    expect(
      await r.waitForNew(
        _active,
        timeout: const Duration(seconds: 20),
        from: mark,
      ),
      isNotNull,
      reason: 'active after play',
    );
    final playing = await r.waitForNew(
      (s) => s.status == PlaybackStatus.playing,
      timeout: const Duration(seconds: 30),
      from: mark,
    );
    note('playing again after play(): ${playing != null}');
  });

  testWidgets('4. jump / next / previous', (tester) async {
    final r = record('4 navigation');
    await player.initialize(_sources, playWhenReady: true);
    expect(await r.waitFor(_active), isNotNull);
    final m2 = r.observations.length;
    await player.jumpToSourceAtIndex(1);
    final jumped = await r.waitForNew(
      (s) => s.currentIndex == 1,
      timeout: const Duration(seconds: 20),
      from: m2,
    );
    expect(jumped, isNotNull, reason: 'currentIndex 1 after jump');
    expect(jumped!.currentSource, _sources[1]);
    note('after jump status=${player.state.status.name}');

    final m3 = r.observations.length;
    await player.nextSource();
    final next = await r.waitForNew(
      (s) => s.currentIndex == 2,
      timeout: const Duration(seconds: 20),
      from: m3,
    );
    expect(next, isNotNull, reason: 'currentIndex 2 after next');

    final m4 = r.observations.length;
    await player.previousSource();
    final prev = await r.waitForNew(
      (s) => s.currentIndex == 1,
      timeout: const Duration(seconds: 20),
      from: m4,
    );
    expect(prev, isNotNull, reason: 'currentIndex 1 after previous');

    final m5 = r.observations.length;
    await player.jumpToSourceAtIndex(0);
    await r.waitForNew((s) => s.currentIndex == 0, from: m5);
    final before = r.observations.length;
    await player.previousSource();
    await Future<void>.delayed(const Duration(seconds: 5));
    final last =
        r.observations.skip(before).map((o) => o.state.currentIndex).toList();
    note(
      'previous at first item: indices observed after call = $last, final index=${player.state.currentIndex}, status=${player.state.status.name}',
    );

    final m6 = r.observations.length;
    await player.jumpToSourceAtIndex(2);
    await r.waitForNew((s) => s.currentIndex == 2, from: m6);
    final before2 = r.observations.length;
    await player.nextSource();
    await Future<void>.delayed(const Duration(seconds: 5));
    final last2 =
        r.observations.skip(before2).map((o) => o.state.currentIndex).toList();
    note(
      'next at last item: indices observed after call = $last2, final index=${player.state.currentIndex}, status=${player.state.status.name}',
    );
  });

  testWidgets('4b. switching source while paused', (tester) async {
    final r = record('4b switch while paused');
    await player.initialize(_sources, playWhenReady: true);
    expect(
      await r.waitFor((s) => s.status == PlaybackStatus.playing),
      isNotNull,
    );
    final m7 = r.observations.length;
    await player.pause();
    await r.waitForNew((s) => s.status == PlaybackStatus.paused, from: m7);
    final m8 = r.observations.length;
    await player.jumpToSourceAtIndex(1);
    await r.waitForNew((s) => s.currentIndex == 1, from: m8);
    await Future<void>.delayed(const Duration(seconds: 8));
    note(
      'after jump while paused: status=${player.state.status.name} (auto-play on switch: ${player.state.status != PlaybackStatus.paused})',
    );
  });

  testWidgets('5. setVolume shows in state and getVolume', (tester) async {
    final r = record('5 volume');
    await player.initialize(_sources, playWhenReady: true);
    expect(await r.waitFor(_active), isNotNull);
    final m9 = r.observations.length;
    await player.setVolume(0.3);
    final changed = await r.waitForNew(
      (s) => (s.volume - 0.3).abs() < 0.01,
      timeout: const Duration(seconds: 10),
      from: m9,
    );
    expect(changed, isNotNull, reason: 'state.volume ~0.3');
    expect(await player.getVolume(), closeTo(0.3, 0.01));
  });

  testWidgets('6. dispose gives idle and initialize works again (x5)', (
    tester,
  ) async {
    final r = record('6 dispose cycles');
    for (var i = 0; i < 5; i++) {
      await player.initialize(_sources, playWhenReady: true);
      final active = await r.waitForNew(_active);
      expect(active, isNotNull, reason: 'cycle $i: active after initialize');
      note('cycle $i active=${active!.status.name}');
      final mark = r.observations.length;
      await player.dispose();
      final sawIdle = await r.waitForNew(
        (s) => s.status == PlaybackStatus.idle,
        timeout: const Duration(seconds: 10),
        from: mark,
      );
      expect(sawIdle, isNotNull, reason: 'cycle $i: idle after dispose');
      await Future<void>.delayed(const Duration(seconds: 3));
      final settled = r.observations.last.state;
      note(
        'cycle $i settled after dispose: ${r.describe(settled)} (state getter: ${player.state.status.name})',
      );
      expect(
        settled.status,
        PlaybackStatus.idle,
        reason:
            'cycle $i: final snapshot after dispose must be idle, was ${r.describe(settled)}',
      );
      expect(settled.currentIndex, isNull);
      expect(player.state.status, PlaybackStatus.idle);
      final afterDispose = r.observations.skip(mark).toList();
      final firstIdle = afterDispose.indexWhere(
        (o) => o.state.status == PlaybackStatus.idle,
      );
      for (final o in afterDispose.skip(firstIdle)) {
        expect(
          o.state.status,
          PlaybackStatus.idle,
          reason: 'cycle $i: left idle again: ${r.describe(o.state)}',
        );
      }
    }
  });

  testWidgets(
      '6b. dispose right after an unawaited initialize completes without error',
      (tester) async {
    final r = record('6b dispose during initialize');
    final init = player.initialize(_sources, playWhenReady: true);
    final disposed = player.dispose();
    await init;
    await disposed;
    await Future<void>.delayed(const Duration(seconds: 3));
    note('settled: ${r.describe(player.state)}');
    expect(player.state.status, PlaybackStatus.idle);
    expect(player.state.currentIndex, isNull);
    await player.initialize(_sources, playWhenReady: true);
    expect(await r.waitForNew(_active), isNotNull,
        reason: 'initialize works after a superseded initialize');
  });

  testWidgets('6c. five back-to-back dispose/initialize cycles, awaited',
      (tester) async {
    final r = record('6c rapid cycles awaited');
    await player.initialize(_sources, playWhenReady: true);
    for (var i = 0; i < 5; i++) {
      await player.dispose();
      await player.initialize(_sources, playWhenReady: true);
    }
    expect(
        await r.waitForNew(_active, from: r.observations.length - 1), isNotNull,
        reason: 'active after the last cycle');
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(player.state.status, isNot(PlaybackStatus.idle),
        reason: 'left idle after rapid cycles: ${r.describe(player.state)}');
    expect(player.state.currentIndex, 0);
  });

  testWidgets('6d. five back-to-back dispose/initialize cycles, not awaited',
      (tester) async {
    final r = record('6d rapid cycles unawaited');
    Future<void>? last;
    for (var i = 0; i < 5; i++) {
      player.dispose();
      last = player.initialize(_sources, playWhenReady: true);
    }
    await last;
    expect(await r.waitForNew(_active), isNotNull,
        reason: 'active after the last cycle');
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(player.state.status, isNot(PlaybackStatus.idle),
        reason: 'left idle after rapid cycles: ${r.describe(player.state)}');
    expect(player.state.currentIndex, 0);
  });

  testWidgets('4c. Android: source switch emits null then the new title',
      (tester) async {
    if (!Platform.isAndroid) return;
    final r = record('4c title around a switch');
    final titles = <String?>[];
    final sub = player.nowPlayingStream.listen((e) => titles.add(e.title));
    await player.initialize(_sources, playWhenReady: true);
    expect(await r.waitFor(_active), isNotNull);
    await Future<void>.delayed(const Duration(seconds: 2));
    titles.clear();
    await player.jumpToSourceAtIndex(1);
    await r.waitForNew((s) => s.nowPlaying?.title == _sources[1].title,
        timeout: const Duration(seconds: 20), from: r.observations.length - 1);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await sub.cancel();
    note('nowPlayingStream around switch: $titles');
    expect(titles.length, greaterThanOrEqualTo(2));
    expect(titles.first, isNull);
    expect(titles[1], _sources[1].title);
  });

  testWidgets('7. unawaited initialize followed by play()', (tester) async {
    final r = record('7 unawaited initialize + play');
    final init = player.initialize(_sources);
    final play = player.play();
    await Future.wait([init, play]);
    final active = await r.waitFor(_active);
    expect(active, isNotNull, reason: 'playback requested');
    final playing = await r.waitFor((s) => s.status == PlaybackStatus.playing);
    note('reached playing: ${playing != null}');
  });

  testWidgets('8. late subscriber receives the current snapshot first', (
    tester,
  ) async {
    final r = record('8 late subscriber');
    await player.initialize(_sources, playWhenReady: true);
    expect(await r.waitFor(_active), isNotNull);
    await Future<void>.delayed(const Duration(seconds: 2));
    final current = r.observations.last.state;
    final first = await player.stateStream.first.timeout(
      const Duration(seconds: 5),
    );
    note(
      'late subscriber first=${r.describe(first)} latest seen by recorder=${r.describe(current)}',
    );
    expect(first.status, isNot(PlaybackStatus.idle));
    expect(first.currentIndex, 0);
    expect(first, player.state);
  });

  testWidgets('9. two listeners; cancelling one keeps the other', (
    tester,
  ) async {
    final r = record('9 two listeners');
    final aState = <RadioPlayerState>[];
    final bState = <RadioPlayerState>[];
    final aPlaying = <bool>[];
    final bPlaying = <bool>[];
    final subs = [
      player.stateStream.listen(aState.add),
      player.stateStream.listen(bState.add),
      player.isPlayingStream.listen(aPlaying.add),
      player.isPlayingStream.listen(bPlaying.add),
    ];
    await player.initialize(_sources, playWhenReady: true);
    expect(
      await r.waitFor((s) => s.status == PlaybackStatus.playing),
      isNotNull,
    );
    expect(aState, isNotEmpty);
    expect(bState.length, aState.length);
    expect(aPlaying, bPlaying);
    note('isPlayingStream so far: $aPlaying');

    await subs[0].cancel();
    await subs[2].cancel();
    final bStateBefore = bState.length;
    final bPlayingBefore = bPlaying.length;
    final m10 = r.observations.length;
    await player.pause();
    await r.waitForNew((s) => s.status == PlaybackStatus.paused, from: m10);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(
      bState.length,
      greaterThan(bStateBefore),
      reason: 'stateStream B still receives',
    );
    expect(bState.last.status, PlaybackStatus.paused);
    expect(
      bPlaying.length,
      greaterThan(bPlayingBefore),
      reason: 'isPlayingStream B still receives',
    );
    expect(bPlaying.last, isFalse);
    note('isPlayingStream B after pause: $bPlaying');
    await subs[1].cancel();
    await subs[3].cancel();
  });

  testWidgets('10a. unresolvable host surfaces an error', (tester) async {
    final r = record('10a invalid host');
    await player.initialize([
      const RadioSource(url: 'https://invalid.invalid/stream', title: 'Bad'),
    ], playWhenReady: true);
    final error = await r.waitFor(
      (s) => s.status == PlaybackStatus.error || s.error != null,
      timeout: const Duration(seconds: 60),
    );
    expect(error, isNotNull, reason: 'no error state');
    note(
      'invalid host error: code=${error!.error?.code.name} message="${error.error?.message}" status=${error.status.name}',
    );
    expect(error.error, isNotNull);
    expect(error.error!.message, isNotEmpty);
  });

  testWidgets('10b. "not a url" (iOS: invalidSource)', (tester) async {
    final r = record('10b not a url');
    await player.initialize([
      const RadioSource(url: 'not a url', title: 'Bad'),
    ], playWhenReady: true);
    final error = await r.waitFor(
      (s) => s.error != null || s.status == PlaybackStatus.error,
      timeout: const Duration(seconds: 60),
    );
    note(
      '"not a url" result: ${error == null ? 'NO ERROR, final state=${player.state}' : 'code=${error.error?.code.name} message="${error.error?.message}" status=${error.status.name} idx=${error.currentIndex}'}',
    );
    if (Platform.isIOS) {
      expect(error, isNotNull);
      expect(error!.error!.code, RadioPlayerErrorCode.invalidSource);
    }
  });
}

extension on _Recorder {
  Duration? timeOfOrNull(PlaybackStatus status) =>
      timeOf((s) => s.status == status);
}
