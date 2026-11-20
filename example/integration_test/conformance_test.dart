import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_radio_player/flutter_radio_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixtures/icy_server.dart';

const _timeout = Duration(seconds: 30);
const _quiet = Duration(seconds: 2);

final player = FlutterRadioPlayer.instance;
late IcyServer server;

List<RadioSource> _stations(int count) => [
  for (var i = 0; i < count; i++)
    RadioSource(url: server.url('/s$i'), title: 'Station $i'),
];

Future<RadioPlayerState> _until(bool Function(RadioPlayerState s) test) {
  if (test(player.state)) return Future.value(player.state);
  return player.stateStream.firstWhere(test).timeout(_timeout);
}

Future<void> _audible() => _until((s) => s.status == PlaybackStatus.playing);

/// Waits a moment and returns how many requests the server received for [path].
Future<int> _requestsTo(String path) async {
  await Future<void>.delayed(_quiet);
  return server.requests.where((r) => r.path == path).length;
}

const _engineBPort = 'frp_engine_b';
const _host = MethodChannel('frp_test_host');

Map<String, Object?> _encode(RadioPlayerState state) => {
  'status': state.status.name,
  'index': state.currentIndex,
  'ids': [for (final s in state.sources) s.id],
  'current': state.currentSource?.title,
};

/// Entry point of the second engine in C11. It obeys commands sent by the test
/// through [IsolateNameServer] and replies with its own view of the state.
@pragma('vm:entry-point')
void secondEngineMain() {
  WidgetsFlutterBinding.ensureInitialized();
  final player = FlutterRadioPlayer.instance;
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(_engineBPort);
  IsolateNameServer.registerPortWithName(port.sendPort, _engineBPort);
  port.listen((message) async {
    final [command as String, argument, reply as SendPort] = message as List;
    Future<RadioPlayerState> until(bool Function(RadioPlayerState) test) =>
        test(player.state)
        ? Future.value(player.state)
        : player.stateStream.firstWhere(test);
    switch (command) {
      case 'awaitStatus':
        await until((s) => s.status.name == argument);
      case 'awaitIndex':
        await until((s) => s.currentIndex == argument);
      case 'setSources':
        await player.setSources([
          for (final [url as String, title as String] in argument! as List)
            RadioSource(url: url, title: title),
        ]);
      case 'next':
        await player.next();
      case 'previous':
        await player.previous();
      case 'stop':
        await player.stop();
    }
    reply.send(_encode(player.state));
  });
}

// ignore: avoid_print
void _step(String name) => print('C11 step $name');

Future<Map<Object?, Object?>> _engineB(
  String command, [
  Object? argument,
]) async {
  SendPort? port;
  final deadline = DateTime.now().add(_timeout);
  while ((port = IsolateNameServer.lookupPortByName(_engineBPort)) == null) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('engine B');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  final reply = ReceivePort();
  port!.send([command, argument, reply.sendPort]);
  final result = await reply.first.timeout(_timeout);
  reply.close();
  return result as Map<Object?, Object?>;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    server = await IcyServer.start(title: 'Song');
    await player.setOptions(const RadioPlayerOptions());
  });

  tearDown(() async {
    await player.setSources(const []);
    await server.close();
  });

  group('C7 volume', () {
    test('a fresh player starts at 1.0', () async {
      expect(player.state.volume, 1.0);
    });

    test('survives setSources and stop, clamps, rejects NaN', () async {
      await player.setVolume(0.3);
      await player.setSources(_stations(2), autoPlay: true);
      await player.stop();
      await player.setSources(_stations(1));
      expect(player.state.volume, closeTo(0.3, 0.001));

      await player.setVolume(1.5);
      expect(player.state.volume, 1.0);
      await expectLater(player.setVolume(double.nan), throwsArgumentError);
      expect(player.state.volume, 1.0);
    });
  });

  group('C2 connect on demand, stop', () {
    test('setSources connects nothing; play, stop, play again', () async {
      final stations = _stations(2);
      await player.setSources(stations);
      expect(player.state.status, PlaybackStatus.paused);
      expect(await _requestsTo('/s0'), 0);

      await player.play();
      expect(player.state.isPlaying, isTrue);
      await _audible();
      final firstConnect = server.requestCount;
      expect(firstConnect, greaterThan(0));

      await player.stop();
      expect(player.state.status, PlaybackStatus.paused);
      expect(player.state.sources, stations);
      expect(player.state.currentIndex, 0);
      expect(player.state.nowPlaying, isNull);
      expect(player.state.error, isNull);

      await player.play();
      await _audible();
      expect(server.requestCount, greaterThan(firstConnect));
    });

    test('autoPlay leaves idle and starts', () async {
      expect(player.state.status, PlaybackStatus.idle);
      await player.setSources(_stations(1), autoPlay: true);
      expect(player.state.isPlaying, isTrue);
      await _audible();
    });

    test('pause gives paused, play returns to playing', () async {
      await player.setSources(_stations(1), autoPlay: true);
      await _audible();
      await player.pause();
      expect(player.state.status, PlaybackStatus.paused);
      expect(player.state.isPlaying, isFalse);
      await player.play();
      expect(player.state.isPlaying, isTrue);
      await _audible();
    });

    test('an empty list while playing gives idle', () async {
      await player.setSources(_stations(2), autoPlay: true);
      await _audible();
      await player.setSources(const []);
      expect(player.state.status, PlaybackStatus.idle);
      expect(player.state.currentIndex, isNull);
      expect(player.state.sources, isEmpty);
    });
  });

  group('C3 wrap-around', () {
    test('wraps at both ends by default', () async {
      await player.setSources(_stations(3), initialIndex: 2);
      await player.next();
      expect(player.state.currentIndex, 0);
      await player.previous();
      expect(player.state.currentIndex, 2);
    });

    test('stops at both ends without wrapAround', () async {
      await player.setOptions(const RadioPlayerOptions(wrapAround: false));
      await player.setSources(_stations(3), initialIndex: 2);
      await player.next();
      expect(player.state.currentIndex, 2);
      await player.setSources(_stations(3), initialIndex: 0);
      await player.previous();
      expect(player.state.currentIndex, 0);
    });

    test('one source: next and previous do nothing', () async {
      await player.setSources(_stations(1));
      final before = player.state;
      await player.next();
      await player.previous();
      expect(player.state, before);
    });
  });

  group('C4 source changes keep the play state', () {
    test(
      'while paused next and previous stay paused and connect nothing',
      () async {
        await player.setSources(_stations(3));
        await player.next();
        expect(player.state.currentIndex, 1);
        expect(player.state.status, PlaybackStatus.paused);
        await player.previous();
        expect(player.state.currentIndex, 0);
        expect(player.state.status, PlaybackStatus.paused);
        expect(server.requestCount, 0);
      },
    );

    test('while playing next keeps playing on the new source', () async {
      await player.setSources(_stations(3), autoPlay: true);
      await _audible();
      await player.next();
      expect(player.state.currentIndex, 1);
      expect(player.state.isPlaying, isTrue);
      expect(player.state.nowPlaying, isNull);
      await _audible();
      expect(await _requestsTo('/s1'), greaterThan(0));
    });

    test('play(index:) from paused plays the new source', () async {
      await player.setSources(_stations(3));
      await player.play(index: 2);
      expect(player.state.currentIndex, 2);
      expect(player.state.isPlaying, isTrue);
      await _audible();
      expect(await _requestsTo('/s0'), 0);
    });

    test('play(index: current) while playing makes no new request', () async {
      await player.setSources(_stations(2), autoPlay: true);
      await _audible();
      final before = await _requestsTo('/s0');
      await player.play(index: 0);
      expect(await _requestsTo('/s0'), before);
      expect(player.state.status, PlaybackStatus.playing);
    });
  });

  group('C5 index and no-source rules', () {
    test(
      'out-of-range play(index:) is a RangeError, state unchanged',
      () async {
        await player.setSources(_stations(2));
        final before = player.state;
        await expectLater(player.play(index: -1), throwsRangeError);
        await expectLater(player.play(index: 2), throwsRangeError);
        expect(player.state, before);
      },
    );

    test('with no sources every transport call is a quiet no-op', () async {
      expect(player.state.status, PlaybackStatus.idle);
      await player.play();
      await player.pause();
      await player.playOrPause();
      await player.stop();
      await player.next();
      await player.previous();
      expect(player.state.status, PlaybackStatus.idle);
      expect(server.requestCount, 0);
    });
  });

  group('C10 repeated lifecycles', () {
    test('setSources, play, stop three times', () async {
      for (var i = 0; i < 3; i++) {
        await player.setSources(_stations(2));
        await player.play();
        await _audible();
        await player.stop();
        expect(player.state.status, PlaybackStatus.paused);
      }
    });

    test('setSources, play, setSources([]) three times', () async {
      for (var i = 0; i < 3; i++) {
        await player.setSources(_stations(2));
        await player.play();
        await _audible();
        await player.setSources(const []);
        expect(player.state.status, PlaybackStatus.idle);
      }
    });

    test('unawaited cycles end in the last requested state', () async {
      for (var i = 0; i < 3; i++) {
        unawaited(player.setSources(_stations(2)));
        unawaited(player.play());
        unawaited(player.setSources(const []));
      }
      await player.setSources(_stations(2));
      await player.play();
      await _audible();
    });
  });

  group('C12 order, completion and list replacement', () {
    test('unawaited setSources then play(index: 2) plays source 2', () async {
      final stations = _stations(3);
      unawaited(player.setSources(stations));
      await player.play(index: 2);
      expect(player.state.sources, stations);
      expect(player.state.currentIndex, 2);
      expect(player.state.isPlaying, isTrue);
      await _audible();
      expect(await _requestsTo('/s2'), greaterThan(0));
      expect(server.requests.where((r) => r.path != '/s2'), isEmpty);
    });

    test('a reordered list keeps the stream and the index follows', () async {
      final stations = _stations(3);
      await player.setSources(stations, initialIndex: 1, autoPlay: true);
      await _audible();
      await _until((s) => s.nowPlaying != null);
      final before = server.requestCount;

      await player.setSources([stations[2], stations[0], stations[1]]);
      expect(player.state.currentIndex, 2);
      expect(player.state.status, PlaybackStatus.playing);
      expect(player.state.nowPlaying?.title, 'Song');
      await Future<void>.delayed(_quiet);
      expect(server.requestCount, before);
    });

    test('a changed title updates without a new request', () async {
      final stations = _stations(2);
      await player.setSources(stations, autoPlay: true);
      await _audible();
      final before = server.requestCount;

      await player.setSources([
        stations[0].copyWith(title: 'Renamed'),
        stations[1],
      ]);
      expect(player.state.currentSource?.title, 'Renamed');
      expect(player.state.status, PlaybackStatus.playing);
      await Future<void>.delayed(_quiet);
      expect(server.requestCount, before);
    });

    test('an explicit initialIndex switches', () async {
      final stations = _stations(3);
      await player.setSources(stations, autoPlay: true);
      await _audible();
      await player.setSources(stations, initialIndex: 2);
      expect(player.state.currentIndex, 2);
      expect(player.state.status, PlaybackStatus.paused);
    });

    test(
      'removing the current source pauses on index 0 unless autoPlay',
      () async {
        final stations = _stations(3);
        await player.setSources(stations, initialIndex: 1, autoPlay: true);
        await _audible();
        await player.setSources([stations[0], stations[2]]);
        expect(player.state.currentIndex, 0);
        expect(player.state.status, PlaybackStatus.paused);

        await player.setSources(stations, initialIndex: 1, autoPlay: true);
        await _audible();
        await player.setSources([stations[0], stations[2]], autoPlay: true);
        expect(player.state.currentIndex, 0);
        expect(player.state.isPlaying, isTrue);
        await _audible();
      },
    );

    test('a late subscriber first sees the current state', () async {
      await player.setSources(_stations(2), autoPlay: true);
      await _audible();
      final first = await player.stateStream.first;
      expect(first, player.state);
    });
  });

  group('C11 two engines share one player', () {
    setUp(() => IsolateNameServer.removePortNameMapping(_engineBPort));
    tearDown(() => _host.invokeMethod<void>('destroySecondEngine'));

    test('state, commands, options and lifetime are shared', () async {
      final stations = _stations(3);
      await player.setSources(stations, autoPlay: true);
      await _audible();

      expect(await _host.invokeMethod<bool>('coreExists'), isTrue);
      _step('0');
      await _host.invokeMethod<void>(
        'spawnSecondEngine',
        PluginUtilities.getCallbackHandle(secondEngineMain)!.toRawHandle(),
      );
      _step('1');
      final seen = await _engineB('awaitStatus', 'playing');
      expect(seen['ids'], [for (final s in stations) s.id]);
      expect(seen['current'], 'Station 0');

      _step('2');
      final requests = server.requestCount;
      await _engineB('setSources', [
        for (final s in stations) [s.url, s.title],
      ]);
      await Future<void>.delayed(_quiet);
      expect(server.requestCount, requests);
      expect(player.state.status, PlaybackStatus.playing);

      _step('3');
      await player.setOptions(const RadioPlayerOptions(wrapAround: false));
      await player.play(index: 2);
      await _engineB('awaitIndex', 2);
      final atEnd = await _engineB('next');
      expect(atEnd['index'], 2);

      _step('4');
      await _engineB('previous');
      await _until((s) => s.currentIndex == 1);

      _step('5');
      await _engineB('stop');
      await _until((s) => s.status == PlaybackStatus.paused);

      _step('6');
      await player.play();
      await _audible();
      await _host.invokeMethod<void>('destroySecondEngine');
      await Future<void>.delayed(_quiet);
      expect(player.state.status, PlaybackStatus.playing);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('E3 cases', () {
    const reason = 'E3: FRP5-078';
    test(
      'C1 status while stalling and playOrPause while loading',
      () {},
      skip: reason,
    );
    test('C6 nowPlaying across switches, artist and song', () {}, skip: reason);
    test('C8 errors, reconnect and invalidSource', () {}, skip: reason);
    test('C9 interruptions and audio focus', () {}, skip: reason);
    test('C13 live resume after a long pause', () {}, skip: reason);
  });
}
