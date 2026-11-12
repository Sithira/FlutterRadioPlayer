import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _badSource = RadioSource(
  url: 'https://invalid.invalid/stream',
  title: 'Unresolvable',
);

const _validSource = RadioSource(
  url: 'https://s2-webradio.antenne.de/chillout?icy=https',
  title: 'Antenne Chillout',
);

const _invalidSource = RadioSource(url: 'not a url', title: 'Invalid');

const _timeout = Duration(seconds: 45);

class _Recorder {
  _Recorder(this.player, this.label) {
    _subscription = player.stateStream.listen((state) {
      observations.add((_clock.elapsed, state));
    });
  }

  final FlutterRadioPlayer player;
  final String label;
  final List<(Duration, RadioPlayerState)> observations = [];
  final Stopwatch _clock = Stopwatch()..start();
  late final StreamSubscription<RadioPlayerState> _subscription;

  Future<RadioPlayerState?> waitForNew(
    PlaybackStatus status, {
    required int from,
  }) async {
    final deadline = _clock.elapsed + _timeout;
    while (_clock.elapsed < deadline) {
      for (var i = from; i < observations.length; i++) {
        if (observations[i].$2.status == status) return observations[i].$2;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  String describe(RadioPlayerState s) {
    final err = s.error == null
        ? ''
        : ' err=${s.error!.code.name}(${s.error!.message})';
    return '${s.status.name}[i=${s.currentIndex}$err]';
  }

  void printLog() {
    final platform = Platform.isAndroid ? 'ANDROID' : 'IOS';
    // ignore: avoid_print
    print(
      'SMOKE[$platform] $label: ${observations.map((o) => '+${o.$1.inMilliseconds}ms ${describe(o.$2)}').join(' -> ')}',
    );
  }

  Future<void> close() => _subscription.cancel();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final player = FlutterRadioPlayer();
  _Recorder? recorder;

  setUp(() async {
    await player.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  tearDown(() async {
    recorder?.printLog();
    await recorder?.close();
    recorder = null;
    await player.dispose();
  });

  Future<void> expectRetry(
    String label,
    Future<void> Function() trigger,
  ) async {
    final r = recorder = _Recorder(player, label);
    await player.initialize([_badSource], playWhenReady: true);
    final firstError = await r.waitForNew(PlaybackStatus.error, from: 0);
    expect(firstError, isNotNull, reason: 'first failure');

    final mark = r.observations.length;
    await trigger();
    final loading = await r.waitForNew(PlaybackStatus.loading, from: mark);
    expect(loading, isNotNull, reason: 'state should leave error for loading');
    expect(loading!.error, isNull);

    final secondError = await r.waitForNew(PlaybackStatus.error, from: mark);
    expect(secondError, isNotNull, reason: 'second failure after retry');
    expect(secondError!.error!.message, isNotEmpty);

    final statuses = r.observations.skip(mark).map((o) => o.$2.status).toList();
    expect(
      statuses.indexOf(PlaybackStatus.loading),
      lessThan(statuses.lastIndexOf(PlaybackStatus.error)),
    );
  }

  testWidgets('play() after a failed stream retries', (tester) async {
    await expectRetry('play retry', player.play);
  });

  testWidgets('playOrPause() from the error state retries', (tester) async {
    await expectRetry('playOrPause retry', player.playOrPause);
  });

  testWidgets('jumping to an invalid source reports error at that index', (
    tester,
  ) async {
    final r = recorder = _Recorder(player, 'invalid entry');
    await player.initialize([
      _validSource,
      _invalidSource,
      _validSource,
    ], playWhenReady: true);
    expect(await r.waitForNew(PlaybackStatus.loading, from: 0), isNotNull);

    var mark = r.observations.length;
    await player.jumpToSourceAtIndex(1);
    final error = await r.waitForNew(PlaybackStatus.error, from: mark);
    expect(error, isNotNull);
    expect(error!.currentIndex, 1);
    expect(error.error, isNotNull);
    final platform = Platform.isAndroid ? 'ANDROID' : 'IOS';
    // ignore: avoid_print
    print(
      'SMOKE[$platform] NOTE: invalid entry code=${error.error!.code.name}',
    );

    mark = r.observations.length;
    await player.nextSource();
    final moved = await r.waitForNew(PlaybackStatus.loading, from: mark);
    expect(moved, isNotNull);
    expect(moved!.currentIndex, 2);
    expect(moved.error, isNull);
  });

  testWidgets('initialize with an empty list while playing gives idle', (
    tester,
  ) async {
    final r = recorder = _Recorder(player, 'empty initialize');
    await player.initialize([_validSource], playWhenReady: true);
    expect(await r.waitForNew(PlaybackStatus.loading, from: 0), isNotNull);

    final mark = r.observations.length;
    await player.initialize([]);
    final idle = await r.waitForNew(PlaybackStatus.idle, from: mark);
    expect(idle, isNotNull);
    expect(idle!.currentIndex, isNull);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(player.state.status, PlaybackStatus.idle);
    expect(player.state.currentIndex, isNull);
  });
}
