import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_radio_player_ios/flutter_radio_player_ios.dart';
import 'package:flutter_radio_player_ios/src/messages.g.dart';
import 'package:flutter_radio_player_platform_interface/flutter_radio_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

RadioPlayerStateMessage _message({
  PlaybackStatusMessage status = PlaybackStatusMessage.paused,
  double volume = 1.0,
  String? title,
  RadioPlayerErrorMessage? error,
}) => RadioPlayerStateMessage(
  status: status,
  sources: [
    RadioSourceMessage(
      id: 'a',
      url: 'https://a.example/s',
      title: 'A',
      artwork: 'art.png',
      headers: {'Authorization': 'Bearer x'},
    ),
    RadioSourceMessage(
      id: 'https://b.example/s',
      url: 'https://b.example/s',
      headers: {},
    ),
  ],
  currentIndex: 0,
  nowPlayingTitle: title,
  volume: volume,
  error: error,
);

class _FakeHostApi implements RadioPlayerHostApi {
  final calls = <String>[];
  RadioPlayerStateMessage reply = _message();
  PlatformException? error;
  List<RadioSourceMessage>? sources;
  RadioPlayerOptionsMessage? options;

  Future<RadioPlayerStateMessage> _record(String call) {
    calls.add(call);
    final error = this.error;
    return error == null ? Future.value(reply) : Future.error(error);
  }

  @override
  Future<RadioPlayerStateMessage> setSources(
    List<RadioSourceMessage> sources,
    int? initialIndex,
    bool autoPlay,
  ) {
    this.sources = sources;
    return _record('setSources(${sources.length}, $initialIndex, $autoPlay)');
  }

  @override
  Future<RadioPlayerStateMessage> setOptions(
    RadioPlayerOptionsMessage options,
  ) {
    this.options = options;
    return _record('setOptions');
  }

  @override
  Future<RadioPlayerStateMessage> play(int? index) => _record('play($index)');

  @override
  Future<RadioPlayerStateMessage> pause() => _record('pause');

  @override
  Future<RadioPlayerStateMessage> playOrPause() => _record('playOrPause');

  @override
  Future<RadioPlayerStateMessage> stop() => _record('stop');

  @override
  Future<RadioPlayerStateMessage> next() => _record('next');

  @override
  Future<RadioPlayerStateMessage> previous() => _record('previous');

  @override
  Future<RadioPlayerStateMessage> setVolume(double volume) =>
      _record('setVolume($volume)');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeHostApi host;
  late StreamController<RadioPlayerStateMessage> events;
  late FlutterRadioPlayerIos platform;

  setUp(() {
    host = _FakeHostApi();
    events = StreamController.broadcast();
    platform = FlutterRadioPlayerIos(
      hostApi: host,
      stateEvents: () => events.stream,
    );
  });

  test('registerWith installs the iOS implementation', () {
    FlutterRadioPlayerIos.registerWith();
    expect(
      FlutterRadioPlayerPlatform.instance,
      isA<FlutterRadioPlayerIos>(),
    );
  });

  group('mapping', () {
    test('state message to model', () {
      final state = stateFromMessage(
        _message(
          status: PlaybackStatusMessage.loading,
          volume: 0.4,
          title: 'Artist - Song',
          error: RadioPlayerErrorMessage(
            code: RadioPlayerErrorCodeMessage.httpStatus,
            message: '503',
          ),
        ),
      );
      expect(state.status, PlaybackStatus.loading);
      expect(state.sources, const [
        RadioSource(
          id: 'a',
          url: 'https://a.example/s',
          title: 'A',
          artwork: 'art.png',
          headers: {'Authorization': 'Bearer x'},
        ),
        RadioSource(url: 'https://b.example/s'),
      ]);
      expect(state.currentIndex, 0);
      expect(state.nowPlaying, const NowPlayingInfo(title: 'Artist - Song'));
      expect(state.volume, 0.4);
      expect(
        state.error,
        const RadioPlayerError(
          code: RadioPlayerErrorCode.httpStatus,
          message: '503',
        ),
      );
      expect(state.isReconnecting, isTrue);
    });

    test('every status and error code maps by name', () {
      for (final status in PlaybackStatusMessage.values) {
        expect(
          stateFromMessage(_message(status: status)).status.name,
          status.name,
        );
      }
      for (final code in RadioPlayerErrorCodeMessage.values) {
        final error = RadioPlayerErrorMessage(code: code, message: 'm');
        expect(
          stateFromMessage(_message(error: error)).error!.code.name,
          code.name,
        );
      }
    });

    test('a missing or empty title is no nowPlaying', () {
      expect(stateFromMessage(_message()).nowPlaying, isNull);
      expect(stateFromMessage(_message(title: '')).nowPlaying, isNull);
    });

    test('mapped sources and headers are unmodifiable', () {
      final state = stateFromMessage(_message());
      expect(
        () => state.sources.add(const RadioSource(url: 'x')),
        throwsUnsupportedError,
      );
      expect(
        () => state.sources.first.headers['k'] = 'v',
        throwsUnsupportedError,
      );
    });

    test('source and options to messages', () {
      final source = sourceToMessage(
        const RadioSource(
          url: 'https://a.example/s',
          title: 'A',
          headers: {'X': '1'},
        ),
      );
      expect(source.id, 'https://a.example/s');
      expect(source.headers, {'X': '1'});

      final options = optionsToMessage(
        const RadioPlayerOptions(
          wrapAround: false,
          reconnect: ReconnectPolicy(giveUpAfter: Duration(seconds: 90)),
          android: AndroidOptions(
            stopOnTaskRemoved: false,
            notificationIcon: 'ic_radio',
          ),
        ),
      );
      expect(options.wrapAround, isFalse);
      expect(options.reconnectGiveUpAfterMillis, 90000);
      expect(options.androidStopOnTaskRemoved, isFalse);
      expect(options.androidNotificationIcon, 'ic_radio');
    });
  });

  group('commands', () {
    test('every command returns the reply state', () async {
      final commands = <Future<RadioPlayerState> Function()>[
        () => platform.setSources(const [RadioSource(url: 'u')]),
        () => platform.setOptions(const RadioPlayerOptions()),
        () => platform.play(),
        () => platform.pause(),
        () => platform.playOrPause(),
        () => platform.stop(),
        () => platform.next(),
        () => platform.previous(),
        () => platform.setVolume(0.5),
      ];
      for (final (i, command) in commands.indexed) {
        host.reply = _message(volume: i / 10);
        expect((await command()).volume, i / 10);
      }
      expect(host.calls, [
        'setSources(1, null, false)',
        'setOptions',
        'play(null)',
        'pause',
        'playOrPause',
        'stop',
        'next',
        'previous',
        'setVolume(0.5)',
      ]);
    });

    test('calls reach the host synchronously, in order', () {
      unawaited(
        platform.setSources(
          const [RadioSource(url: 'u')],
          initialIndex: 0,
          autoPlay: true,
        ),
      );
      unawaited(platform.play(index: 2));
      expect(host.calls, ['setSources(1, 0, true)', 'play(2)']);
    });

    test('setSources sends ids, urls and headers', () async {
      await platform.setSources(const [
        RadioSource(url: 'https://a.example/s', id: 'a', headers: {'X': '1'}),
      ]);
      expect(host.sources!.single.id, 'a');
      expect(host.sources!.single.headers, {'X': '1'});
    });

    test('invalid_index becomes a RangeError', () async {
      host.error = PlatformException(
        code: 'invalid_index',
        message: 'index 5 of 2',
      );
      await expectLater(
        platform.play(index: 5),
        throwsA(
          isA<RangeError>().having((e) => e.message, 'message', 'index 5 of 2'),
        ),
      );
    });

    test('other platform errors pass through', () async {
      host.error = PlatformException(code: 'other');
      await expectLater(platform.pause(), throwsA(isA<PlatformException>()));
    });
  });

  test('stateStream maps native snapshots', () async {
    final states = <RadioPlayerState>[];
    platform.stateStream.listen(states.add);
    events
      ..add(_message(status: PlaybackStatusMessage.playing))
      ..add(_message(status: PlaybackStatusMessage.playing));
    await pumpEventQueue();
    expect(states, hasLength(2));
    expect(states.first.status, PlaybackStatus.playing);
    expect(identical(platform.stateStream, platform.stateStream), isTrue);
  });
}
