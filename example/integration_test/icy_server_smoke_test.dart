import 'dart:io' show Platform;

import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixtures/icy_server.dart';

const _timeout = Duration(seconds: 30);

Future<RadioPlayerState> _waitFor(
  FlutterRadioPlayer player,
  bool Function(RadioPlayerState state) test,
) {
  if (test(player.state)) return Future.value(player.state);
  return player.stateStream.firstWhere(test).timeout(_timeout);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late IcyServer server;
  final player = FlutterRadioPlayer.instance;

  setUp(() async => server = await IcyServer.start(title: 'Smoke Title'));

  tearDown(() async {
    await player.setSources(const []);
    await server.close();
  });

  testWidgets('plays the local ICY stream and follows title changes', (
    tester,
  ) async {
    final sources = [
      RadioSource(url: server.url('/a'), title: 'Station A'),
      RadioSource(url: server.url('/b'), title: 'Station B'),
    ];

    await player.setSources(sources);
    expect(player.state.status, PlaybackStatus.paused);
    expect(player.state.sources, sources);
    expect(player.state.currentIndex, 0);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(server.requestCount, 0, reason: 'setSources must not connect');

    await player.play();
    expect(player.state.isPlaying, isTrue);

    final playing = await _waitFor(
      player,
      (s) =>
          s.status == PlaybackStatus.playing &&
          s.nowPlaying?.title == 'Smoke Title',
    );
    expect(playing.error, isNull);
    expect(server.requestCount, greaterThanOrEqualTo(1));

    server.setTitle('Second Title');
    await _waitFor(player, (s) => s.nowPlaying?.title == 'Second Title');

    final requestsBefore = server.requestCount;
    await player.setSources([
      RadioSource(url: server.url('/c'), title: 'Station C'),
      ...sources,
    ]);
    expect(player.state.currentIndex, 1);
    expect(player.state.isPlaying, isTrue);
    expect(player.state.nowPlaying?.title, 'Second Title');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(server.requestCount, requestsBefore, reason: 'kept stream');

    await player.next();
    expect(player.state.currentIndex, 2);
    expect(player.state.nowPlaying, isNull);
    expect(player.state.isPlaying, isTrue);
    await _waitFor(player, (s) => s.status == PlaybackStatus.playing);

    await player.stop();
    expect(player.state.status, PlaybackStatus.paused);
    expect(player.state.nowPlaying, isNull);
    expect(player.state.sources, hasLength(3));

    await expectLater(player.play(index: 9), throwsRangeError);

    await player.setVolume(0.4);
    expect(player.state.volume, closeTo(0.4, 0.001));

    await player.setSources(const []);
    expect(player.state.status, PlaybackStatus.idle);
    expect(player.state.currentIndex, isNull);

    // ignore: avoid_print
    print(
      'ICY_SMOKE[${Platform.operatingSystem}] requests=${server.requestCount} '
      'paths=${server.requests.map((r) => r.path).toList()}',
    );
  });
}
